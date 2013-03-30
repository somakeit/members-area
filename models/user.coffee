module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'User', {
    id: {type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true}
    email: {type: DataTypes.STRING, allowNull: false, unique: true, validate:{isEmail:true}}
    username: {type: DataTypes.STRING, allowNull: false, unique: true}
    password: {type: DataTypes.STRING, allowNull: false}
    admin: {type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false}
    paid_until: {type: DataTypes.DATE, allowNull: true}
    fullname: {type: DataTypes.STRING, allowNull: false}
    address: {type: DataTypes.TEXT, allowNull: false}
    wikiname: {type: DataTypes.STRING, allowNull:true}
    approved: {type: DataTypes.DATE, allowNull: true}
    data: {type:DataTypes.TEXT, allowNull: false}
  }, {timestamps: true}
