
module.exports = (app) -> new class
  cards: (req, res) ->
    if(req.cookies.SECRET == req.secret)
      console.log(req.User)
      r = req.User.findAll("")
      r.error (err) ->
        res.json 404, {error: "Error getting users"}
      r.success (models) ->
        data = {}
        for model in models
          user = model.toJSON()
          try
            user.data = JSON.parse user.data
          console.log(user.data.cards)
          for card in user.data.cards
            if card
              data[card] = {'username': user.username, 'fullname': user.fullname}
        res.json data
    else
      res.json 401, {error: "failed to auth request"}
