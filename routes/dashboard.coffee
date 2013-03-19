module.exports = (app) -> new class
  index: (req, response) ->
    response.render 'dashboard', {title: 'Dashboard'}
