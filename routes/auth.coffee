module.exports.socialProvider = (socialProvider) ->
  (req, res, next) ->
    query = where: {}
    query.where[socialProvider + 'Id'] = req.user.id
    r = req.User.find query
    r.error next
    r.success  (user) ->
      if user
        if user.isApproved()
            req.session.userId = user.id
            req.session.fullname = user.fullname
            req.session.username = user.username
            req.session.admin = user.admin
        res.redirect '/'
      else if req.session.userId
        r = req.User.find(req.session.userId)
        r.success (user) ->
          user[socialProvider + 'Id'] = req.user.id
          r = user.save()
          r.success  (user) ->
            res.redirect '/account'
          r.error next
        r.error next
      else
        res.render 'message', {title:'Error', text: 'We cannot find an account linked to the provided social profile. Try logging in with your email/password instead.'}