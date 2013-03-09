express = require 'express'
routes = require './routes'
user = require './routes/user'
http = require 'http'
path = require 'path'

require './env'

app = express()

app.configure ->
  app.use require('stylus').middleware(path.join(__dirname, 'public'))
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

http.createServer(app).listen app.get('port'), ->
  console.log("Express server listening on port " + app.get('port'))
