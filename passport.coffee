###*
 * Provides Authentication Strategies. Exports the Passport.js
 * (http://passportjs.org/) object
###

###*
 * Module Dependencies
###

passport = require 'passport'
models = require './models'
env = require './env'
LocalStrategy = require('passport-local').Strategy
GitHubStrategy = require('passport-github').Strategy
FacebookStrategy = require('passport-facebook').Strategy
TwitterStrategy = require('passport-twitter').Strategy

###*
 * Shared Stragegy Helpers
###

passport.serializeUser = (user, done) ->
  done null, user.id

passport.deserializeUser = (id, done) ->
  query = models.User.find id
  query.success (user) ->
    done null, user
  query.error done

###*
 * GitHub Auth
###

if env.GITHUB_ID and env.GITHUB_SECRET
  passport.use new GitHubStrategy(
    clientID: env.GITHUB_ID
    clientSecret: env.GITHUB_SECRET
    callbackURL: env.SERVER_ADDRESS + '/auth/github/callback'
  , (accessToken, refreshToken, profile, done) ->
    done null, profile
  )

###*
 * Facebook Auth
###

if env.FACEBOOK_ID and env.FACEBOOK_SECRET
  passport.use new FacebookStrategy(
    clientID: env.FACEBOOK_ID
    clientSecret: env.FACEBOOK_SECRET
    callbackURL: env.SERVER_ADDRESS + '/auth/facebook/callback'
  , (accessToken, refreshToken, profile, done) ->
      done null, profile
  )

###*
 * Twitter Auth
###

if env.TWITTER_KEY and env.TWITTER_SECRET
  console.log 'registering twitter'
  passport.use new TwitterStrategy(
    consumerKey: env.TWITTER_KEY
    consumerSecret: env.TWITTER_SECRET
    callbackURL: env.SERVER_ADDRESS + "/auth/twitter/callback"
  , (token, tokenSecret, profile, done) ->
    done null, profile
  )

###*
 * Exports
###

module.exports = passport
