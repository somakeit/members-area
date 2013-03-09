{sqz, Sequelize} = require '../sequelize'

module.exports = sqz.define 'User', {
  id: {type: Sequelize.STRING, primaryKey: true, autoIncrement: true}
  email: {type: Sequelize.STRING, unique: true, validate:{isEmail:true}}
  fullname: {type: Sequelize.STRING}
  address: {type: Sequelize.TEXT}
  wikiname: {type: Sequelize.STRING, allowNull:true}
  approved: {type: Sequelize.DATE, allowNull: true}
  data: {type:Sequelize.TEXT}
}, {timestamps: true}
