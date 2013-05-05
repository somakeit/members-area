gocardlessMod = require '../gocardless-client'
gocardlessClient = gocardlessMod.client

module.exports = (app) -> new class
  index: (req, response) ->
    response.locals.loggedInUser.getPayments().done (err, payments) ->
      if !err
        payments.sort (a, b) -> return +b.made - a.made
      else
        req.error err
      response.render 'subscription', {title: 'Subscription', payments: payments, err: err, gocardlessErr: null, data: null}
  gocardless: (req, response) ->
    loggedInUser = response.locals.loggedInUser
    render = (data, err) ->
      return response.render 'subscription-gocardless', {data: data, title: 'GoCardless', gocardlessErr: err}
    if req.method is 'POST' and req.body.form is 'gocardless'
      {date, monthly, initial} = req.body
      err = new Error()
      tmp = date.split(/-/)
      if tmp.length is 3
        yyyy = parseInt tmp[0], 10
        mm = parseInt tmp[1], 10
        dd = parseInt tmp[2], 10
        if isNaN(yyyy) or isNaN(mm) or isNaN(dd)
          err.date = "Invalid date"
        else
          date = new Date()
          date.setYear yyyy
          date.setMonth mm-1
          date.setDate dd
        tomorrow = new Date()
        tomorrow.setHours(0)
        tomorrow.setMinutes(0)
        tomorrow.setSeconds(0)
        tomorrow.setDate(tomorrow.getDate()+1)
        nextMonth = new Date()
        nextMonth.setMonth(nextMonth.getMonth()+1)
        nextMonth.setHours(23)
        nextMonth.setMinutes(59)
        nextMonth.setSeconds(59)
        if +date < +tomorrow
          err.date = "Earliest date allowed is tomorrow"
        if +date > +nextMonth
          err.date = "Date is too far in the future"
      else
        err.date = "Invalid date - must by YYYY-MM-DD"
      monthly = parseFloat monthly
      if isNaN(monthly)
        err.monthly = "Invalid amount"
      else if monthly < 5
        err.monthly = "Minimum subscription is £5/mo"
      else if monthly > 250
        err.monthly = "Wow, that's generous! If you're serious, please talk to the trustees."
      initial = parseFloat initial
      if isNaN(initial) or initial < 0
        err.initial = "Invalid amount"
      if err.date or err.monthly or err.initial
        return render(req.body, err)
      # Go talk to GoCardless
      addFee = (a) -> Math.ceil(100*100/99 * a)/100
      monthly = addFee monthly
      initial = addFee initial
      now = new Date()
      tmp = loggedInUser.fullname.split(" ")
      firstName = tmp[0]
      lastName = tmp[tmp.length-1]
      tmp = loggedInUser.address.match /[A-Z]{2}[0-9]{1,2}\s*[0-9][A-Z]{2}/
      if tmp
        postcode = tmp[0]
      address1 = loggedInUser.address
      if postcode
        address1 = address1.replace(postcode, "")
      pad = response.locals.pad
      parameters =
        name: "M#{response.locals.pad(loggedInUser.id, 6)}"
        description: "So Make It Subscription"
        #interval_count
        start_at: date
        #expires_at
        #redirect_uri
        #cancel_uri
        #state
        user:
          first_name: firstName
          last_name: lastName
          email: loggedInUser.email
          account_name: loggedInUser.fullname
          billing_address1: address1
          billing_postcode: postcode
        setup_fee: initial
      url = gocardlessClient.newSubscriptionUrl monthly, 1, 'month', parameters
      response.redirect url
    else if req.query.signature
      # We've got a response!
      console.log JSON.stringify req.query
      gocardlessClient.confirmResource req.query, (err, res) ->
        if err
          return response.render 'message', {title:"Error", text: "We couldn't complete the transaction, GoCardless returned an error: '#{err.message}'"}
        else
          response.render 'message', {title:"Done", text: "Thanks for being super-awesome, you super-awesome person you!"}
    else
      render()
