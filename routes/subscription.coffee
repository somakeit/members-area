module.exports = (app) -> new class
  index: (req, response) ->
    response.locals.loggedInUser.getPayments().done (err, payments) ->
      payments.sort (a, b) -> return +b.made - a.made
      response.render 'subscription', {title: 'Subscription', payments: payments, err: err, gocardlessErr: null}
  gocardless: (req, response) ->
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
      response.render 'message', {title: "Unimplemented", text: "Unimplemented (£#{monthly}/mo starting #{response.locals.formatDate(date)} plus initial £#{initial}"}
    else
      render()
