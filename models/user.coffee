bcrypt = require 'bcrypt'

module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'User', {
    id: {type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true}
    email: {type: DataTypes.STRING, allowNull: false, unique: true, validate:{isEmail:true}}
    username: {type: DataTypes.STRING, allowNull: false, unique: true}
    password: {type: DataTypes.STRING, allowNull: false}
    admin: {type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false}
    paidUntil: {type: DataTypes.DATE, allowNull: true}
    fullname: {type: DataTypes.STRING, allowNull: false}
    address: {type: DataTypes.TEXT, allowNull: false}
    wikiname: {type: DataTypes.STRING, allowNull:true}
    approved: {type: DataTypes.DATE, allowNull: true}
    data: {type:DataTypes.TEXT, allowNull: false}
  }, {
    timestamps: true
    classMethods:
      findByPostBody: (body, cb) ->
        {email, password} = body
        if email.match /@/
          query = where:{email:email}
        else
          query = where:{username:email}
        r = @find(query)
        r.error (err) ->
          return cb err
        r.success (user) ->
          if !user
            err = new Error()
            err.code = 404
            return cb err
          bcrypt.compare password, user.password, (err, res) ->
            if err or !res
              err = new Error()
              err.code = 403
              return cb err
            else
              return cb null, user
    instanceMethods:
      getData: ->
        data = null
        try
          data = JSON.parse @data
        return data ? {}

      setData: (data) ->
        if typeof data isnt 'object'
          throw new Error("Tried to set data to non-object")
        @data = JSON.stringify data

      getDataKey: (key) ->
        data = @getData()
        return data[key]

      setDataKey: (key, value) ->
        data = @getData()
        if typeof value is 'undefined'
          delete data[key]
        else
          data[key] = value
        @setData data

      isApproved: ->
        if @isRejected()
          return false
        approved = @approved
        return (approved? and approved.getFullYear() > 2012)

      isRejected: ->
        rejected = @getDataKey 'rejected'
        return (!!rejected)
  }
