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

  reminders: (req, response, next) ->
    if !response.locals.loggedInUser.admin
      return next()
    # Only show people 15 days overdue or more
    ymd = new Date()
    ymd.setDate(ymd.getDate() - 15)
    ymd = response.locals.formatDate ymd
    query = where: """
        approved IS NOT NULL AND
        approved > '2013-01-01' AND
        (
          paidUntil IS NULL OR
          paidUntil < '#{ymd}'
        )
      """
    r = req.User.findAll(query)
    r.success (users) ->
      response.render 'reminders', {title: "Reminders", users: users, bcc: process.env.TRUSTEES_ADDRESS}
    r.error (err) ->
      response.render 'message', {title:"Error", text: "Unknown error occurred, please try again later."}
