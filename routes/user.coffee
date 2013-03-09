User = require '../models/user'

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
    unless /^[^@]+@[^@]+.[^@]+$/.test req.body.email
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
        response.render 'registrationComplete', {title:"Registration complete", email: req.body.email}
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
