express = require 'express'
http = require 'http'
path = require 'path'
nib = require 'nib'
stylus = require('stylus')
fs = require 'fs'
net = require 'net'

# Fix/load/check environmental variables
require './env'

app = express()

user = require('./routes/user')(app)
dashboard = require('./routes/dashboard')(app)
subscription = require('./routes/subscription')(app)

stylusCompile = (str, path) ->
  return stylus(str)
    .set('filename', path)
    .set('compress', true)
    .use(nib())

app.configure ->
  app.locals.requiredVotes = process.env.REQUIRED_VOTES
  # Export the template name to templates
  app.use (req, res, next) ->
    render = res.render
    res.render = (templateName) ->
      res.locals.templateName = templateName
      return render.apply this, arguments
    next()

  app.use stylus.middleware
    src: path.join(__dirname, 'public')
    compile: stylusCompile
  app.use express.static(path.join(__dirname, 'public'))
  app.set 'port', process.env.PORT ? 1337
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.favicon(path.join(__dirname, 'public', 'img', 'favicon.png'))
  app.use express.logger('dev')
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser(process.env.SECRET ? 'your secret here')
  app.use express.session()
  app.use user.auth
  app.use app.router

app.configure 'development', ->
  app.use express.errorHandler()

# Logged out
app.all '/register', user.register
app.all '/verify', user.verify
app.all '/forgot', user.forgot

# Logged in
app.all '/', dashboard.index
app.all '/user', user.list
app.all '/user/:userId', user.view
app.all '/subscription', subscription.index

# This MUST come last!
handle404 = (req, res) ->
  res.statusCode = 404
  res.render 404, {title:"Not Found"}

app.use handle404

listen = (port) ->
  http.createServer(app).listen port, ->
    if typeof port is 'string'
      fs.chmod port, '0666'
    console.log "Express server listening on port " + port

port = app.get('port')
if typeof port is 'string'
  # Unix socket - see if it's in use
  socket = new net.Socket
  socket.on 'connect', ->
    console.error "Socket in use"
    process.exit 1
  socket.on 'error', (err) ->
    if err?.code is 'ECONNREFUSED'
      # No-one's listening
      fs.unlink port, (err) ->
        if err
          console.error "Couldn't delete old socket."
          process.exit 1
        console.log "Liberated unused socket."
        listen port
    else
      console.error "Socket '#{port}' in use? #{err}"
      process.exit 1
  socket.connect port
else
  # TCP socket
  listen port
