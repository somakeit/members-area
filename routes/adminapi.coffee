env = require '../env'
module.exports = (app) -> new class
  cards: (req, res) ->
    if ! env.CARD_SECRET
      res.json 500, {error: "no security configured"}
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
            if(data[card])
              data[card] = {'username': data[card].username + ", and " + user.username, 'fullname': data[card].fullname + ", and " + user.fullname}
            else
              data[card] = {'username': user.username, 'fullname': user.fullname}

        res.json data
    else
      res.json 401, {error: "failed to auth request"}
