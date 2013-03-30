module.exports = (app) -> new class
  index: (req, response) ->
    response.locals.loggedInUser.getPayments().done (err, payments) ->
      payments.sort (a, b) -> return +b.made - a.made
      response.render 'subscription', {title: 'Subscription',payments: payments,err:err}
