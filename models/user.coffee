{sqz, Sequelize} = require '../sequelize'

module.exports = sqz.define 'User', {
  id: {type: Sequelize.STRING, primaryKey: true, autoIncrement: true}
  email: {type: Sequelize.STRING, allowNull: false, unique: true, validate:{isEmail:true}}
  username: {type: Sequelize.STRING, allowNull: false, unique: true}
  password: {type: Sequelize.STRING, allowNull: false}
  admin: {type: Sequelize.BOOLEAN, allowNull: false, defaultValue: false}
  fullname: {type: Sequelize.STRING, allowNull: false}
  address: {type: Sequelize.TEXT, allowNull: false}
  wikiname: {type: Sequelize.STRING, allowNull:true}
  approved: {type: Sequelize.DATE, allowNull: true}
  data: {type:Sequelize.TEXT, allowNull: false}
}, {timestamps: true}
