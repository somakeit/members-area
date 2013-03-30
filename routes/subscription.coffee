module.exports = (app) -> new class
  index: (req, response) ->
    response.locals.loggedInUser.getPayments().done (err, payments) ->
      payments.sort (a, b) -> return +b.made - a.made
      formatDate = response.locals.formatDate
      columns =
        made:
          t: 'Payment date'
          f: formatDate
        amount:
          t: 'Amount'
          f: (t) ->
            t = parseInt t
            pounds = Math.floor t/100
            pence = t % 100
            p = response.locals.pad
            return "£#{pounds}.#{p pence}"
        type:
          t: 'Type'
          f: (t) -> t.toUpperCase()
        subscription_from:
          t: 'Description'
          f: (t, entry) ->
            diff = +entry.subscription_until - entry.subscription_from
            diff /= 30 * 24 * 60 * 60 * 1000
            diff = Math.round diff
            duration = diff + " month" + (if diff is 1 then "" else "s")
            from = formatDate entry.subscription_from
            return "#{duration} from #{from}"
      response.render 'subscription', {title: 'Subscription',payments: payments,err:err, columns: columns}
