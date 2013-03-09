{sqz, Sequelize} = require './sequelize'
require './models/user'

sqz.sync().error (err) ->
  console.error err
