module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'Payment', {
    id: {type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true}
    user_id: {type:DataTypes.INTEGER, allowNull: false, index: true}
    amount: {type:DataTypes.INTEGER, allowNull: false} # In pennies!
    made: {type: DataTypes.DATE, allowNull: false}
    subscription_from: {type: DataTypes.DATE, allowNull: false}
    subscription_until: {type: DataTypes.DATE, allowNull: false}
    data: {type:DataTypes.TEXT, allowNull: false} # JSON
  }, {timestamps: true}
