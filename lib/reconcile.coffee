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

_reconcile = ({User, Payment}, transactions, callback) ->
  result = {warnings:[]}
  done = (err) ->
    return callback err if err
    callback null, result
  processTransaction = (transaction, next) ->
    req = User.find({include:[Payment], id:transaction.userId}).done (err, user) ->
      return next err if err
      if !user?
        result.warnings.push "Unknown user: #{transaction.userId}"
        return next()
      for payment in user.payments
        if payment.made.toFormat('YYYY-MM-DD') is transaction.ymd and payment.amount is transaction.amount and payment.type is transaction.type
          return next()
      # type, amount, made, subscriptionFrom, subscriptionUntil, data
      data =
        type: transaction.type
        amount: transaction.amount
        made: transaction.date
        subscriptionFrom: user.paidUntil ? user.approved
        data:
          original: transaction
      data.subscriptionUntil = new Date(data.subscriptionFrom)
      data.subscriptionUntil.setMonth(data.subscriptionUntil.getMonth()+1)
      payment = Payment.create data
      user.addPayment payment
      user.paidUntil = data.subscriptionUntil
      user.save().done (err, res) ->
        return next err if err
        return next()
  async.eachSeries transactions, processTransaction, done

reconcile = ({User, Payment}, transactions, callback) ->
  # Only run one reconcile at a time to prevent conflicts
  reconcileQueue.addTask (done) ->
    _reconcile {User, Payment}, transactions, ->
      callback.apply @, arguments
      done()

importAndReconcile = ({User, Payment}, filename, callback) ->
  parse filename, (err, transactions) ->
    return callback err if err?
    reconcile {User, Payment}, transactions, callback

module.exports = {parse, reconcile, importAndReconcile}

if require.main is module
  # We were ran directly
  parse process.argv[2], (err, parsed) ->
    throw err if err
    console.log parsed
