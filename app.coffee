express = require 'express'
routes = require './routes'
user = require './routes/user'
http = require 'http'
path = require 'path'
nib = require 'nib'
stylus = require('stylus')

require './env'

app = express()

stylusCompile = (str, path) ->
  return stylus(str)
    .set('filename', path)
    .set('compress', true)
    .use(nib())

app.configure ->
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

app.get '/', routes.index
app.all '/register', user.register
app.all '/verify', user.verify
app.all '/forgot', user.forgot

# This MUST come last!
handle404 = (req, res) ->
  res.statusCode = 404
  res.render 404, {title:"Not Found"}

app.use handle404

http.createServer(app).listen app.get('port'), ->
  console.log("Express server listening on port " + app.get('port'))
