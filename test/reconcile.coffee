chai = require 'chai'
expect = chai.expect

# Why would you not want this?!
chai.Assertion.includeStack = true

CustomEventEmitter = require 'sequelize/lib/emitters/custom-event-emitter'

importer = require('../lib/reconcile')

describe 'OFX import', ->
  it 'should pass an error if file not found', (done) ->
    importer.parse 'non-existent-file.ofx', (err, res) ->
      expect(res).to.not.exist
      expect(err).to.exist
      done()

  it 'should pass a list of transactions on success', (done) ->
    importer.parse 'example.ofx', (err, res) ->
      expect(err).to.not.exist
      expect(res).to.be.an 'array'
      done()

  describe 'example transactions', ->
    transactions = null

    before (done) ->
      importer.parse 'example.ofx', (err, res) ->
        expect(err).to.not.exist
        expect(res).to.be.an 'array'
        transactions = res
        done()

    it 'should contain the expected properties on each record', (done) ->
      for transaction in transactions
        expect(transaction.type).to.be.a 'string'
        expect(transaction.ymd).to.match /^20[0-9]{2}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$/
        expect(transaction.date).to.be.a 'date'
        expect(transaction.amount).to.be.a 'number'
        expect(transaction.amount).to.equal parseInt(transaction.amount, 10)
        expect(transaction.amount).to.be.greaterThan 0
        expect(transaction.name).to.be.a 'string'
        expect(transaction.name).to.not.be.empty
        expect(transaction.accountHolder).to.be.a 'string'
        expect(transaction.accountHolder).to.not.be.empty
        expect(transaction.userId).to.satisfy (userId) ->
          return true if !userId?
          return false if typeof userId isnt 'number'
          return false if userId <= 0
          return false if userId isnt parseInt(userId, 10)
          return true
      done()

    it 'should contain 4 valid records', ->
      expect(transactions.length).to.equal 4
      matched = 0
      for transaction in transactions
        if transaction.userId is 1
          matched++
          expect(transaction.accountHolder).to.equal 'Alice Appleby'
          expect(transaction.type).to.equal 'BGC'
          expect(transaction.amount).to.equal 437
          expect(transaction.ymd).to.equal "2007-03-29"
        if transaction.userId is 10
          matched++
          expect(transaction.accountHolder).to.equal 'John Hancock'
          expect(transaction.type).to.equal 'STO'
          expect(transaction.amount).to.equal 10000
          expect(transaction.ymd).to.equal "2007-07-09"
        if transaction.userId is 11
          matched++
          expect(transaction.accountHolder).to.equal 'Kenny'
          expect(transaction.type).to.equal 'BGC'
          expect(transaction.amount).to.equal 1001
          expect(transaction.ymd).to.equal "2007-07-12"
      expect(matched).to.equal 3

    it 'should be in ascending date order', ->
      expect(transactions[0].date).to.be.lessThan transactions[1].date

describe 'reconciliation', ->
  transactions = null

  before (done) ->
    importer.parse 'example.ofx', (err, res) ->
      expect(err).to.not.exist
      expect(res).to.be.an 'array'
      transactions = res
      done()

  class MockModel
    @create: (details) ->
      return new @(details)

    constructor: (details) ->
      for own k, v of details
        @[k] = v

    save: ->
      promise = new CustomEventEmitter (emitter) ->
        process.nextTick ->
          emitter.emit 'success'
      return promise.run()

  class MockPayment extends MockModel

  class MockUser extends MockModel
    @find: ({id, include}) ->
      expect(include.length).to.equal 1
      expect(include).to.include MockPayment

      promise = new CustomEventEmitter (emitter) ->
        process.nextTick ->
          emitter.emit 'success', mockUsers[id]
      return promise.run()

    constructor: (details, @payments = []) ->
      super

    addPayment: (p) ->
      @payments.push p

  monthsAgo = new Date()
  monthsAgo.setMonth(monthsAgo.getMonth()-8)

  yesterday = new Date()
  yesterday.setDate(yesterday.getDate()-1)

  aMonthFromYesterday = new Date(yesterday.getTime())
  aMonthFromYesterday.setMonth(aMonthFromYesterday.getMonth()+1)

  mockUsers = {
    "1": new MockUser {id: 1, fullname: "Alice Appleby", paidUntil: aMonthFromYesterday, approved: yesterday}, [
      new MockPayment {made: new Date("2007-03-29"), amount: 500, type: "STO"}
      new MockPayment {made: new Date("2007-03-29"), amount: 437, type: "BGC"}
      new MockPayment {made: new Date("2007-03-29"), amount: 1500, type: "OTHER"}
    ]
    "10": new MockUser {id: 10, fullname: "John Hancock", paidUntil: yesterday, approved: monthsAgo}, [
      new MockPayment {made: new Date("2007-03-29"), amount: 437, type: "STO"}
      new MockPayment {made: new Date("2007-03-29"), amount: 437, type: "BGC"}
    ]
    "11": new MockUser {id: 11, fullname: "Kenny", paidUntil: null, approved: yesterday}, []
  }

  worksTest = (done) ->
    importer.reconcile {User:MockUser, Payment:MockPayment}, transactions, (err, res) ->
      expect(err).to.not.exist

      describe 'results', ->
        it 'should not update user 1', ->
          expect(mockUsers[1].payments.length).to.equal 3
          expect(mockUsers[1].paidUntil).to.exist
          expect(mockUsers[1].paidUntil.toFormat('YYYY-MM-DD')).to.equal aMonthFromYesterday.toFormat('YYYY-MM-DD')

        it 'should update user 10', ->
          expect(mockUsers[10].payments.length).to.equal 3
          expect(mockUsers[10].paidUntil.toFormat('YYYY-MM-DD')).to.equal aMonthFromYesterday.toFormat('YYYY-MM-DD')

        it 'should update user 11', ->
          expect(mockUsers[11].payments.length).to.equal 1
          expect(mockUsers[11].paidUntil.toFormat('YYYY-MM-DD')).to.equal aMonthFromYesterday.toFormat('YYYY-MM-DD')

        it 'new payment one', ->
          newPayment = mockUsers[10].payments[2]
          expect(newPayment.made.toFormat("YYYY-MM-DD")).to.equal "2007-07-09"
          expect(newPayment.amount).to.equal 10000
          expect(newPayment.type).to.equal 'STO'

        it 'new payment two', ->
          newPayment = mockUsers[11].payments[0]
          expect(newPayment.made.toFormat("YYYY-MM-DD")).to.equal "2007-07-12"
          expect(newPayment.amount).to.equal 1001
          expect(newPayment.type).to.equal 'BGC'

        it 'should raise a warning', ->
          expect(res).to.be.a 'object'
          expect(res.warnings).to.exist
          expect(res.warnings.length).to.equal 1
          # Unknown user 12
          expect(res.warnings[0]).to.match /unknown.* 12/i

        done()

  it 'should work well', worksTest
  it 'should be idempotent', worksTest
  it 'should be really idempotent', worksTest
