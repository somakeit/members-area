require './env'
models = require './models/'

models.sequelize.sync().error (err) ->
  console.error err
