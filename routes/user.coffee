User = require '../models/user'
nodemailer = require 'nodemailer'

gmail = nodemailer.createTransport "SMTP", {
  service: "Gmail",
  auth: {
    user: process.env.EMAIL_USERNAME
    pass: process.env.EMAIL_PASSWORD
  }
}

exports.auth = (req, response, next) ->
  if req.session.userId? or req.path is '/register'
    return next()
  render = (opts = {}) ->
    opts.err ?= null
    opts.data ?= {}
    opts.title = "Login"
    response.render 'login', opts
  if req.method is 'POST' and req.body.form is 'login' and req.body.username?
    # Check data
    {username, password} = req.body
    r = User.find(where:{username:username})
    r.error (err) ->
      return render({data:req.body,err})
    r.success (user) ->
      if !user
        return render {data:req.body,err:new Error()}
      console.log user.password
      return render()
    return
  return render()

exports.register = (req, response) ->
  render = (opts = {}) ->
    opts.err ?= null
    opts.data ?= {}
    opts.title = "Register"
    response.render 'register', opts
  if req.method is 'POST' and req.body.form is 'register'
    error = new Error()
    unless /^[^@\s,"]+@[^@\s,]+\.[^@\s,]+$/.test req.body.email
      error.email = true
    unless /.+ .*/.test req.body.fullname
      error.fullname = true
    unless req.body.address.length > 8
      error.address = true
    unless req.body.terms is 'on'
      error.terms = true
    if error.email or error.fullname or error.address or error.terms
      render(err:error, data: req.body)
    else
      # Attempt registration
      letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
      validationCode = ""
      for i in [0..7]
        validationCode += letters[Math.floor Math.random()*letters.length]
      r = User.create {
        email: req.body.email
        fullname: req.body.fullname
        address: req.body.address
        wikiname: req.body.wikiname ? null
        data: JSON.stringify {
          newEmail: req.body.email
          validationCode: validationCode
        }
      }
      r.success (user) ->
        # Send them the email
        verifyURL = "http://members.somakeit.org.uk/verify?id=#{user.id}&validationCode=#{validationCode}"
        gmail.sendMail {
          from: "So Make It <web@somakeit.org.uk>"
          to: req.body.email
          subject: "SoMakeIt: verify your email address"
          body: """
            Thanks for registering! Please verify your email address by clicking the link below:

            #{verifyURL}

            Thanks,

            The So Make It web team
            """
        }, (err, res) ->
          if err
            console.error "Error sending registration email."
            console.error err
          response.render 'registrationComplete', {title:"Registration complete", email: req.body.email, err: err}
      r.error (err) ->
        console.error "Error registering user:"
        console.error err
        if err.code is 'ER_DUP_ENTRY'
          err.email = true
          err.email409 = true
        else
          err.unknown = true
        render(err: err, data: req.body)
    return


  render()
