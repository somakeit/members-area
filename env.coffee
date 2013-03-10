fs = require 'fs'
path = require 'path'

# Import the .env as if it were environmental variables
try
  envContents = fs.readFileSync path.join(__dirname, '.env'), 'utf8'
  for line in envContents.split /\n/ when matches = line.match /^([^=]+)=(.*)$/
    process.env[matches[1]] ?= matches[2]

requiredEnvironmentalVars = [
  'SECRET'
  'EMAIL_USERNAME'
  'EMAIL_PASSWORD'
  'APPROVAL_TEAM_EMAIL'
  'SERVER_ADDRESS'
]

unless process.env.SQLITE
  requiredEnvironmentalVars.push 'MYSQL_HOST', 'MYSQL_DATABASE', 'MYSQL_USERNAME', 'MYSQL_PASSWORD'

missing = (name for name in requiredEnvironmentalVars when !process.env[name]?)
if missing.length
  console.error "The following environmental variables are missing: #{missing.join(", ")}"
  process.exit 1

unless process.env.SERVER_ADDRESS.match /^http.*[^/]$/
  console.error "Server address must not end in /"
  process.exit 1
