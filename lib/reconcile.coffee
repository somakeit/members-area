require 'date-utils'
ofx = require 'ofx'
fs = require 'fs'
async = require 'async'

regex = /^(.*) M(0[0-9]+) ([A-Z]{3})$/

reconcileQueue = new class
  constructor: ->
    @tasks = []
    @running = false

  _runNext: =>
    if @tasks.length
      task = @tasks.shift()
      @running = true
      task(@_runNext)
    else
      @running = false

  addTask: (fn) ->
    @tasks.push fn
    if !@running
      @_runNext()

parse = (filename, callback) ->
  fs.readFile filename, 'utf8', (err, ofxData) ->
    if err
      return callback err
    data = ofx.parse ofxData
    output = []
    for tx in data.transactions ? []
      if (matches = tx.name?.match(regex))
        tx.accountHolder = matches[1]
        tx.userId = parseInt matches[2], 10
        tx.type = matches[3]
        tx.ymd = tx.date.toFormat 'YYYY-MM-DD'
        output.push tx
      #else
      #  console.log tx
    output.sort (a, b) -> a.date - b.date
    callback null, output

_reconcile = ({User, Payment}, transactions, callback, dryRun=false) ->
  result = {success:[], warnings:[], duplicates: []}
  dryRun = !!dryRun
  result.dryRun = dryRun
  done = (err) ->
    return callback err if err
    callback null, result
  processTransaction = (transaction, next) ->
    req = User.find(transaction.userId).done (err, user) ->
      return next err if err
      if !user?
        result.warnings.push "Unknown member: £#{transaction.amount/100} (#{transaction.type}) payment for member #{transaction.userId} on #{transaction.ymd}, not adding"
        return next()
      Payment.findAll({where:{UserId:user.id}}).done (err, userPayments) ->
        return next err if err
        for payment in userPayments
          if new Date(payment.made).toFormat('YYYY-MM-DD') is transaction.ymd and payment.amount is transaction.amount and payment.type is transaction.type
            result.duplicates.push "Already added £#{transaction.amount/100} (#{transaction.type}) payment for member #{user.id} (#{user.username}) on #{transaction.ymd}, not adding again"
            return next()
        # type, amount, made, subscriptionFrom, subscriptionUntil, data
        data =
          UserId: user.id
          type: transaction.type
          amount: transaction.amount
          made: transaction.date
          subscriptionFrom: user.paidUntil ? user.approved
          data: JSON.stringify({original: transaction})
        forced = ""
        if transaction.until
          data.subscriptionUntil = transaction.until
          forced = "*"
        else
          data.subscriptionUntil = new Date(data.subscriptionFrom)
          data.subscriptionUntil.setMonth(data.subscriptionUntil.getMonth()+1)
        result.success.push "Added £#{data.amount/100} (#{data.type}) payment for member #{user.id} (#{user.username}) on #{data.made.toFormat('YYYY-MM-DD')} to cover #{data.subscriptionFrom.toFormat('YYYY-MM-DD')} until #{forced}#{data.subscriptionUntil.toFormat('YYYY-MM-DD')}#{forced}."
        if dryRun
          return next()
        else
          Payment.create(data).done (err, payment) ->
            return next err if err
            user.paidUntil = data.subscriptionUntil
            user.save().done (err, res) ->
              return next err if err
              return next()
  async.eachSeries transactions, processTransaction, done

reconcile = ({User, Payment}, transactions, callback, dryRun) ->
  # Only run one reconcile at a time to prevent conflicts
  reconcileQueue.addTask (done) ->
    cb = ->
      callback.apply @, arguments
      done()
    _reconcile {User, Payment}, transactions, cb, dryRun

importAndReconcile = ({User, Payment}, filename, callback, dryRun) ->
  parse filename, (err, transactions) ->
    return callback err if err?
    reconcile {User, Payment}, transactions, callback, dryRun

module.exports = {parse, reconcile, importAndReconcile}

if require.main is module
  # We were ran directly
  parse process.argv[2], (err, parsed) ->
    throw err if err
    console.log parsed
