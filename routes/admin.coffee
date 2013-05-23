require 'date-utils'
fs = require 'fs'
async = require 'async'
gocardlessMod = require '../gocardless-client'
gocardlessClient = gocardlessMod.client

reconcile = require '../lib/reconcile'

module.exports = (app) -> new class
  money: (req, response, next) ->
    if !response.locals.loggedInUser.admin
      return next()
    render = (ofxResults = null, gocardlessResults = null) ->
      r = req.Payment.findAll(include:[req.User])
      r.success (payments) ->
        payments ?= []
        payments.sort (a, b) -> return +b.made - a.made
        normal = response.locals.paymentColumns
        cols =
          user:
            t: "User"
            f: (v) ->
              v?.username ? "-"
        for k, v of normal
          cols[k] = v
        response.render 'money', {title:"Banking", payments:payments, allPaymentColumns:cols, ofxResults: ofxResults, gocardlessResults: gocardlessResults}
      r.error (err) ->
        response.render 'message', {title:"Error", text: "Unknown error occurred, please try again later."}
    if req.method is 'POST' and req.files?.ofxfile?
      path = req.files.ofxfile.path
      next = (err, result) ->
        fs.unlink path
        if err
          console.error err
          response.render 'message', {title:"Error", text: "Error occurred: #{err}"}
        else
          render(result)
      dryRun = !req.body.commit
      if !!req.body.dryRun
        dryRun = true # Just in case they send both
      reconcile.importAndReconcile req, path, next, dryRun
      return
    else if req.method is 'POST' and req.body.form is 'gocardless'
      dryRun = !req.body.commit
      if !!req.body.dryRun
        dryRun = true # Just in case they send both
      gocardlessClient.apiGet "/merchants/#{gocardlessClient.merchant_id}/bills", (err, bills) ->
        paidSubscriptions = []
        done = ->
          next = (err, results) ->
            if err
              response.render 'message', {title:"Error", text: "Error occurred: #{err}"}
            else
              render(null, results)
          paidSubscriptions.sort (a, b) -> a.date - b.date
          reconcile.reconcile req, paidSubscriptions, next, dryRun
        processBill = (bill, next) ->
          if bill.source_type is 'subscription'
            # Find out more
            gocardlessClient.apiGet "/subscriptions/#{bill.source_id}", (err, subscription) ->
              if subscription?
                matches = subscription.name.match /^M0+([0-9]+)$/
                if matches
                  userId = parseInt matches[1], 10
                  billCreated = new Date(bill.created_at)
                  subscriptionStart = new Date(subscription.start_at)
                  billCreatedPlusOneMonth = new Date(+billCreated)
                  billCreatedPlusOneMonth.setMonth(billCreatedPlusOneMonth.getMonth()+1)
                  transaction =
                    userId: userId
                    type: "GC"
                    ymd: billCreated.toFormat 'YYYY-MM-DD'
                    amount: parseInt(parseFloat(bill.amount) * 100, 10)
                    date: billCreated
                    data: {gocardlessBill:bill, gocardlessSubscription: subscription}
                  transaction.status = switch bill.status
                    when 'withdrawn' then 'received'
                    when 'paid' then 'sent'
                    else bill.status
                  if bill.is_setup_fee
                    transaction.until = subscriptionStart
                  paidSubscriptions.push transaction
              next()
          else
            next()

        async.each bills, processBill, done

    else
      render()
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
        approved < '#{ymd}' AND
        (
          paidUntil IS NULL OR
          paidUntil < '#{ymd}'
        )
      """
    r = req.User.findAll(query)
    r.success (users) ->
      body = """
      Dear {{NAME}},

      This email is a reminder that your membership for So Make It is {{DURATION}} overdue. To resolve this, please visit the secure members site by clicking the link below:

      https://members.somakeit.org.uk/subscription

      There are a number of options for payment of your subscription, in order of our preference they are:
      Set up a standing order with your bank (see link above for details; there is no charge for this)
      Quickly and easily set up a Direct Debit online via GoCardless.com (see link above for details; GoCardless charges a tiny 1% per transaction fee)
      Pay in cash at the space (talk to a trustee)
      Set up a payment via PayPal (talk to a trustee first; PayPal charges a £0.20 + 3.4% per transaction fee)
      Remember: the membership fee is still based on a "pay what you feel the space is worth" system so we ask you to pay what you can afford and what you feel access to the space is worth to you. There's bills to pay, equipment to buy and we'll need a significant amount of cash reserved for when our arrangement with rideride expires at the end of September, so please be generous.

      We estimate that we need an average of at least £20/member/mo to survive the year, but we're aware that some members cannot afford that, so minimum membership is set at £5/mo. Current statistics put our 13 paying members at an average of £19.59/mo; though when you factor in the 17 members who've not yet got around to paying that drops significantly to £8.49/mo.

      If you no longer wish to be a member you must tell us in writing, since you are already on our register of members. You'll still be able to join us at our monthly meetup (last Tuesday of every month) and talk about your projects, share ideas and even do some light hacking and tinkering. You are also welcome to come along to regular opening times as a guest and see what we do. As treasurer I’m very happy to discuss money matters or any issues. Alternatively, if you prefer, you can contact the other trustees directly who will be happy to help.

      Thank you for your support.

      Chris Smith
      So Make It Treasurer
      """
      response.render 'reminders', {title: "Reminders", users: users, bcc: process.env.TRUSTEES_ADDRESS, body: body}
    r.error (err) ->
      response.render 'message', {title:"Error", text: "Unknown error occurred, please try again later."}
