require 'date-utils'
ofx = require 'ofx'
fs = require 'fs'

regex = /^(.*) M(0[0-9]+) ([A-Z]{3})$/

parse = (filename, callback) ->
  fs.readFile filename, 'utf8', (err, ofxData) ->
    if err
      console.error err
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

exports.reconcile = (req, filename, callback) ->
  parse filename, (err, parsed) ->
    console.log parsed

if require.main is module
  # We were ran directly
  parse process.argv[2], (err, parsed) ->
    throw err if err
    console.log parsed
