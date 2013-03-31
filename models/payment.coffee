module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'Payment', {
    id: {type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true}
    user_id: {type:DataTypes.INTEGER, allowNull: false, index: true}
    type: {type:DataTypes.STRING, allowNull: false}
    amount: {type:DataTypes.INTEGER, allowNull: false} # In pennies!
    made: {type: DataTypes.DATE, allowNull: false}
    subscriptionFrom: {type: DataTypes.DATE, allowNull: false}
    subscriptionUntil: {type: DataTypes.DATE, allowNull: false}
    data: {type:DataTypes.TEXT, allowNull: false} # JSON
  }, {timestamps: true}
