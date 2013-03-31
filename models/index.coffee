Sequelize = require 'sequelize'

host = process.env.MYSQL_HOST
database = process.env.MYSQL_DATABASE
username = process.env.MYSQL_USERNAME
password = process.env.MYSQL_PASSWORD

sequelize = new Sequelize database, username, password, {
  host: host

  dialect: if process.env.SQLITE then 'sqlite' else 'mysql'
  storage: process.env.SQLITE_PATH || './db.sqlite'

  define: {
    charset: 'utf8'
    collate: 'utf8_general_ci'
  }
}

models = [
  "User"
  "Payment"
]
for model in models
  module.exports[model] = sequelize.import __dirname + "/" + model.toLowerCase()

m = module.exports
m.Payment.belongsTo m.User
m.User.hasMany m.Payment

module.exports.sequelize = sequelize
