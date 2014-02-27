env = require '../env'
module.exports = (app) -> new class
  cards: (req, res) ->
    if req.cookies.SECRET is env.CARD_SECRET
      r = req.User.findAll()
      r.error (err) ->
        res.json 404, {error: "Error getting users"}
      r.success (models) ->
        data = {}
        for model in models
          user = model.toJSON()
          try
            userData = JSON.parse user.data
          userData ?= {}
          for card in userData.cards ? [] when card?.length
            data[card] = {'username': user.username, 'fullname': user.fullname}
        res.json data
    else
      res.json 401, {error: "failed to auth request"}
