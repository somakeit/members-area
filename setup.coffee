{sqz, Sequelize} = require './sequelize'
require './models/user'
require './models/payment'

sqz.sync().error (err) ->
  console.error err
