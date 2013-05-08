gocardless = require 'gocardless'
client = new gocardless.Client
  app_id: process.env.GOCARDLESS_APP_ID
  app_secret: process.env.GOCARDLESS_APP_SECRET
  access_token: process.env.GOCARDLESS_TOKEN
  merchant_id: process.env.GOCARDLESS_MERCHANT
  environment: process.env.GOCARDLESS_ENVIRONMENT ? 'sandbox'

exports.gocardless = gocardless
exports.client = client
