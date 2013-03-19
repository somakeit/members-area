module.exports = (app) -> new class
  index: (req, response) ->
    response.render 'subscription', {title: 'Subscription'}
