winston = require 'winston'
require './env'
models = require './models/'

models.sequelize.sync().error (err) ->
  winston.error err
