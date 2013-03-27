{sqz, Sequelize} = require '../sequelize'

module.exports = sqz.define 'Payment', {
  id: {type: Sequelize.INTEGER, primaryKey: true, autoIncrement: true}
  user_id: {type:Sequelize.INTEGER, allowNull: false, index: true}
  amount: {type:Sequelize.INTEGER, allowNull: false} # In pennies!
  made: {type: Sequelize.DATE, allowNull: false}
  subscription_from: {type: Sequelize.DATE, allowNull: false}
  subscription_until: {type: Sequelize.DATE, allowNull: false}
  data: {type:Sequelize.TEXT, allowNull: false} # JSON
}, {timestamps: true}
