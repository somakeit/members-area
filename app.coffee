require('source-map-support').install()
express = require 'express'
http = require 'http'
path = require 'path'
nib = require 'nib'
stylus = require('stylus')
fs = require 'fs'
net = require 'net'

# Fix/load/check environmental variables
require './env'
models = require './models'

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
  app.set('trust proxy', true) # Required for nginx/etc
  app.locals.requiredVotes = process.env.REQUIRED_VOTES
  # Export the template name to templates
  app.use (req, res, next) ->
    req[k] = v for k, v of models
    render = res.render
    res.render = (templateName) ->
      res.locals.templateName = templateName
      return render.apply this, arguments
    pad = res.locals.pad = (n, l=2, p="0") ->
      n = ""+n
      if n.length < l
        n = new Array(l - n.length + 1).join(p) + n
      return n
    formatDate = res.locals.formatDate = (d) ->
      return (d.getFullYear())+"-"+pad(d.getMonth()+1)+"-"+pad(d.getDate())
    res.locals.paymentColumns =
      made:
        t: 'Payment date'
        f: formatDate
      amount:
        t: 'Amount'
        f: (t) ->
          t = parseInt t
          pounds = Math.floor t/100
          pence = t % 100
          return "£#{pounds}.#{pad pence}"
      type:
        t: 'Type'
        f: (t) -> t.toUpperCase()
      subscription_from:
        t: 'Description'
        f: (t, entry) ->
          diff = +entry.subscription_until - entry.subscription_from
          diff /= 30 * 24 * 60 * 60 * 1000
          diff = Math.round diff
          duration = diff + " month" + (if diff is 1 then "" else "s")
          from = formatDate entry.subscription_from
          return "#{duration} from #{from}"
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

handle501 = (req, res) ->
  res.statusCode = 501
  tmp = req.path.match /^\/([^/]+)(\/|$)/
  area = 'unknown'
  if tmp
    area = tmp[1]
  res.render 501, {title:"Unimplemented Found", templateName: area}

app.all '/account', handle501
app.all '/account/*', handle501
app.all '/admin', handle501
app.all '/admin/*', handle501

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
