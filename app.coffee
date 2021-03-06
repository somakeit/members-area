require('source-map-support').install()
express = require 'express'
http = require 'http'
path = require 'path'
nib = require 'nib'
stylus = require('stylus')
fs = require 'fs'
net = require 'net'
winston = require 'winston'

process.chdir __dirname

# Fix/load/check environmental variables
require './env'

passport = require './passport'

models = require './models'

try
  fs.mkdirSync 'log'

winston.remove winston.transports.Console
winston.add winston.transports.Console, timestamp: true, colorize: true
winston.add winston.transports.File, {filename: "log/winston.log", maxsize: 50000000, maxFiles: 8, level: 'warn'}
winston.handleExceptions new winston.transports.File {filename: 'log/crash.log'}

app = express()

user = require('./routes/user')(app)
dashboard = require('./routes/dashboard')(app)
subscription = require('./routes/subscription')(app)
admin = require('./routes/admin')(app)
auth = require './routes/auth'
adminapi = require('./routes/adminapi')(app)

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
      subscriptionFrom:
        t: 'Description'
        f: (t, entry) ->
          diff = +entry.subscriptionUntil - entry.subscriptionFrom
          diff /= 30 * 24 * 60 * 60 * 1000
          diff = Math.round diff
          duration = diff + " month" + (if diff is 1 then "" else "s")
          from = formatDate entry.subscriptionFrom
          return "#{duration} from #{from}"
      status:
        t: 'Status'
        f: (t, entry) ->
          entry.getData().status ? 'received'
    next()

  app.use stylus.middleware
    src: path.join(__dirname, 'public')
    compile: stylusCompile
  app.use express.static(path.join(__dirname, 'public'))
  app.set 'port', process.env.PORT ? 1337
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.favicon(path.join(__dirname, 'public', 'img', 'favicon.png'))

  # Request logging
  logStream = fs.createWriteStream 'log/access.log', {flags: 'a', mode: 0o600}
  express.logger.token 'user', (req, res) ->
    return res.locals.loggedInUser?.id ? "-"
  express.logger.token 'ips', (req, res) ->
    ips = req.ips.slice()
    if ips.indexOf(req.ip) is -1
      ips.unshift(req.ip)
    return ips.join(",")
  app.use express.logger
    stream: logStream
    format: ':ips - - [:date] ":method :url HTTP/:http-version" :status :res[content-length] ":referrer" ":user-agent" - :response-time ms (u::user)'
    buffer: true
  if process.env.NODE_ENV is 'development'
    # Also log to console
    app.use express.logger('dev')

  # Winston logging
  app.use (req, res, next) ->
    req.winston = winston
    details =
    wrap = (fn) ->
      return (args...) ->
        details = {method: req.method, path: req.path, ip: req.ip}
        if res.locals.loggedInUser?
          details.userId = res.locals.loggedInUser.id
          details.username = res.locals.loggedInUser.username
        fn args, details
    req.info = wrap winston.info
    req.log = req.info
    req.warn = wrap winston.warn
    req.error = wrap winston.error
    return next()

  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser(process.env.SECRET ? 'your secret here')
  app.use express.session()
  app.use passport.initialize()
  app.use user.auth
  app.use app.router

app.configure 'development', ->
  app.use express.errorHandler()

# Logged out
app.all '/register', user.register
app.all '/verify', user.verify
app.all '/forgot', user.forgot
app.all '/reapply', user.reapply

# Social auth
app.get '/auth/facebook', passport.authenticate('facebook')
app.get '/auth/facebook/callback', passport.authenticate('facebook'), auth.socialProvider('facebook')

app.get '/auth/github', passport.authenticate('github')
app.get '/auth/github/callback', passport.authenticate('github'), auth.socialProvider('github')

app.get '/auth/twitter', passport.authenticate('twitter')
app.get '/auth/twitter/callback', passport.authenticate('twitter'), auth.socialProvider('twitter')

# API-like
app.post '/me', user.me
app.get '/exists', user.exists

# Logged in
app.all '/', dashboard.index
app.all '/logout', user.logout
app.all '/user', user.list
app.all '/account', user.account
app.all '/user/:userId', user.view
app.all '/subscription', subscription.index
app.all '/subscription/gocardless', subscription.gocardless
app.all '/viewRegister', user.viewRegister
app.all '/admin/money', admin.money
app.all '/admin/reminders', admin.reminders
app.all '/admin/emails', admin.emails

# restricted API-like
app.get '/adminapi/cards', adminapi.cards

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
    winston.info "Express server listening on port " + port

port = app.get('port')
if typeof port is 'string'
  # Unix socket - see if it's in use
  socket = new net.Socket
  socket.on 'connect', ->
    winston.error "Socket in use"
    process.exit 1
  socket.on 'error', (err) ->
    if err?.code is 'ECONNREFUSED'
      # No-one's listening
      fs.unlink port, (err) ->
        if err
          winston.error "Couldn't delete old socket."
          process.exit 1
        winston.info "Liberated unused socket."
        listen port
    else if err?.code is 'ENOENT'
      listen port
    else
      winston.error "Socket '#{port}' in use? #{err}"
      process.exit 1
  socket.connect port
else
  # TCP socket
  listen port
