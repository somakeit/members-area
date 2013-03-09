fs = require 'fs'
path = require 'path'

# Import the .env as if it were environmental variables
try
  envContents = fs.readFileSync path.join(__dirname, '.env'), 'utf8'
  for line in envContents.split /\n/ when matches = line.match /^([^=]+)=(.*)$/
    process.env[matches[1]] ?= matches[2]
