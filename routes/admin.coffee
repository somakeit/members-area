gocardlessMod = require '../gocardless-client'
gocardlessClient = gocardlessMod.client

module.exports = (app) -> new class
  money: (req, response, next) ->
    if !response.locals.loggedInUser.admin
      return next()
    r = req.Payment.findAll(include:['User'])
    r.success (payments) ->
      payments ?= []
      payments.sort (a, b) -> return +b.made - a.made
      normal = response.locals.paymentColumns
      console.log payments
      cols =
        user:
          t: "User"
          f: (v) ->
            v?.username ? "-"
      for k, v of normal
        cols[k] = v
      response.render 'money', {title:"Banking", payments:payments, allPaymentColumns:cols}
    r.error (err) ->
      response.render 'message', {title:"Error", text: "Unknown error occurred, please try again later."}
    return
    response.locals.loggedInUser.getPayments().done (err, payments) ->
      if !err
        payments.sort (a, b) -> return +b.made - a.made
      else
        req.error err
      response.render 'subscription', {title: 'Subscription', payments: payments, err: err, gocardlessErr: null, data: null}
