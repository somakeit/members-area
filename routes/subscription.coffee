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
        if loggedInUser.paidUntil && +loggedInUser.paidUntil > +nextMonth
          nextMonth = new Date(+loggedInUser.paidUntil)
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
      addFee = (a) -> Math.round(100*100/99 * a)/100
      monthly = addFee monthly
      initial = addFee initial
      now = new Date()
      tmp = loggedInUser.fullname.split(" ")
      firstName = tmp[0]
      lastName = tmp[tmp.length-1]
      address = loggedInUser.address
      tmp = address.match /[A-Z]{2}[0-9]{1,2}\s*[0-9][A-Z]{2}/i
      if tmp
        postcode = tmp[0].toUpperCase()
        address = address.replace(tmp[0], "")
      tmp = address.split /[\n\r,]/
      tmp = tmp.filter (a) -> a.replace(/\s+/g, "").length > 0
      tmp = tmp.filter (a) -> !a.match /^(hants|hampshire)$/
      for potentialTown, i in tmp
        t = potentialTown.replace /[^a-z]/gi, ""
        if t.match /^(southampton|soton|eastleigh|chandlersford|winchester|northbaddesley|havant|portsmouth|bournemouth|poole|bognorregis|romsey|lyndhurst|eye|warsash|lymington)$/i
          town = potentialTown
          tmp.splice i, 1
          break
      town ?= "Southamton"

      if tmp.length > 1
        address2 = tmp.pop()
      address1 = tmp.join(", ")

      pad = response.locals.pad
      parameters =
        name: "M#{response.locals.pad(loggedInUser.id, 6)}"
        description: "So Make It Subscription"
        #interval_count
        start_at: date
        #expires_at
        #redirect_uri
        #cancel_uri
        state: JSON.stringify {uid: loggedInUser.id, initial: initial, monthly: monthly, start_at: +date, created: +new Date()}
        user:
          first_name: firstName
          last_name: lastName
          email: loggedInUser.email
          account_name: loggedInUser.fullname
          billing_address1: address1
          billing_address2: address2
          billing_town: town
          billing_postcode: postcode
        setup_fee: initial
      url = gocardlessClient.newSubscriptionUrl monthly, 1, 'month', parameters
      response.redirect url
    else if req.query.signature
      # We've got a response!
      state = null
      try
        state = JSON.parse (req.query.state ? "")
      unless state
        return response.render 'message', {title:"Error", text: "We couldn't complete the transaction, are you sure you did it all correctly?"}
      unless state.uid is loggedInUser.id
        return response.render 'message', {title:"Error", text: "We couldn't complete the transaction, you're not the same person that started it?"}
      delete state.uid

      gocardlessClient.confirmResource req.query, (err, res) ->
        if err
          return response.render 'message', {title:"Error", text: "We couldn't complete the transaction, GoCardless returned an error: '#{err.message}'"}
        else
          try
            data = JSON.parse loggedInUser.data
          data ?= {}
          data.gocardless = state
          loggedInUser.data = JSON.stringify data
          r = loggedInUser.save()
          r.success ->
            response.render 'message', {title:"Done", text: "Thanks for being super-awesome, you super-awesome person you!"}
          r.error (err) ->
            response.render 'message', {title:"Done, but...", text: "Your subscription was set up, but we've not been able to store that fact for some technical reason or other. This doesn't really matter..."}
    else
      render()
