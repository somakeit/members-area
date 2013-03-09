Sequelize = require 'sequelize'
require './env'

host = process.env.MYSQL_HOST
database = process.env.MYSQL_DATABASE
username = process.env.MYSQL_USERNAME
password = process.env.MYSQL_PASSWORD

sqz = new Sequelize database, username, password, {
  host: host
  define: {
    charset: 'utf8'
    collate: 'utf8_general_ci'
  }
}

module.exports = {Sequelize, sqz}
