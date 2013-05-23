module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'Payment', {
    id: {type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true}
    type: {type:DataTypes.STRING, allowNull: false}
    amount: {type:DataTypes.INTEGER, allowNull: false} # In pennies!
    made: {type: DataTypes.DATE, allowNull: false}
    subscriptionFrom: {type: DataTypes.DATE, allowNull: false}
    subscriptionUntil: {type: DataTypes.DATE, allowNull: false}
    data: {type:DataTypes.TEXT, allowNull: false} # JSON
  }, {
    timestamps: true
    instanceMethods:
      getData: ->
        data = null
        try
          data = JSON.parse @data
        return data ? {}
      setData: (data) ->
        @data = JSON.stringify data
  }
