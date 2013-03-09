User = require '../models/user'
nodemailer = require 'nodemailer'
bcrypt = require 'bcrypt'

gmail = nodemailer.createTransport "SMTP", {
  service: "Gmail",
  auth: {
    user: process.env.EMAIL_USERNAME
    pass: process.env.EMAIL_PASSWORD
  }
}

exports.auth = (req, response, next) ->
  if req.session.userId? or ['/register', '/verify'].indexOf(req.path) isnt -1
    return next()
  render = (opts = {}) ->
    opts.err ?= null
    opts.data ?= {}
    opts.title = "Login"
    response.render 'login', opts
  if req.method is 'POST' and req.body.form is 'login' and req.body.email?
    # Check data
    {email, password} = req.body
    r = User.find(where:{email:email})
    r.error (err) ->
      return render({data:req.body,err})
    r.success (user) ->
      if !user
        return render {data:req.body,err:new Error()}
      bcrypt.compare password, user.password, (err, res) ->
        if err or !res
          return render {data:req.body,err:new Error()}
        else
          response.render 'message', {title:"Logged in", text: "Done..."}
    return
  return render()

exports.verify = (req, response) ->
  {id, validationCode} = req.query ? {}
  id = parseInt(id, 10)
  validationCode = ""+validationCode
  fail = ->
    response.statusCode = 400
    response.render 'message', {title: "Invalid parameters", text: "Something went wrong - please check the email again."}
  success = ->
    response.render 'message', {title: "Validation complete", text: "Thanks! We'll be in touch shortly... "}
  if isNaN(id) or id <= 0 or validationCode.length isnt 8
    fail()
  else
    r = User.find(id)
    r.fail (err) ->
      fail()
    r.success (user) ->
      if !user
        return fail()

      data = {}
      try
        data = JSON.parse user.data

      if !data.validationCode?
        success()
      else if data.validationCode is validationCode
        delete data.validationCode

        user.email = data.email ? user.email
        delete data.email
        delete data.validationCode
        user.data = JSON.stringify data

        r = user.save()
        r.error (err) ->
          console.error "Error saving validated user."
          console.error err
          response.render 'message', {title: "Database issue", text: "Please try again later."}
        r.success ->
          success()
      else
        fail()

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
    unless req.body.password.length >= 6
      error.password = true
    unless req.body.password is req.body.password2
      error.password = true
      error.passwordsdontmatch = true
    if error.email or error.fullname or error.address or error.terms or error.password
      render(err:error, data: req.body)
    else
      # Attempt registration
      letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
      validationCode = ""
      for i in [0..7]
        validationCode += letters[Math.floor Math.random()*letters.length]
      bcrypt.hash req.body.password, 10, (err, hash) ->
        if err
          return fail()
        r = User.create {
          email: req.body.email
          password: hash
          fullname: req.body.fullname
          address: req.body.address
          wikiname: req.body.wikiname ? null
          data: JSON.stringify {
            email: req.body.email
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
