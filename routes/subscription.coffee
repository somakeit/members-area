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
          date = new Date(yyyy, mm-1, dd)
        if +date < +new Date()
          err.date = "Earliest date allowed is tomorrow"
        if +date > (+new Date() + (24*60*60*1000 * 28 * 3))
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
      url = "https://sandbox.gocardless.com/connect/subscriptions/new"
      letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/"
      now = new Date()
      nonce = ""
      for i in [0...16]
        nonce += letters.substr(Math.floor(Math.random()*letters.length), 1)
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
        client_id: process.env.GOCARDLESS_APP_ID
        nonce: nonce
        timestamp: "#{response.locals.formatDate(now)}T#{pad(now.getUTCHours())}:#{pad(now.getUTCMinutes())}:00Z"
        subscription:
          amount: monthly
          merchant_id: process.env.GOCARDLESS_MERCHANT
          interval_length: 1
          interval_unit: 'month'
          name: "M#{response.locals.pad(loggedInUser.id, 6)}"
          description: "So Make It Subscription"
          start_at: response.locals.formatDate(date) # ISO8601
          setup_fee: initial
        user:
          first_name: firstName
          last_name: lastName
          email: loggedInUser.email
          account_name: "So Make It"
          billing_address1: address1
          billing_postcode: postcode

      response.render 'message', {title: "Unimplemented", text: "Unimplemented (£#{monthly}/mo starting #{response.locals.formatDate(date)} plus initial £#{initial}. #{JSON.stringify(parameters)}"}
    else
      render()
