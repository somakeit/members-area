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
 * Local Auth
###

passport.use new LocalStrategy((username, password, done) ->
  User.findOne
    username: username
  , (err, user) ->
    return done(err)  if err
    unless user
      return done(null, false,
        message: 'Incorrect username.'
      )
    unless user.validPassword(password)
      return done(null, false,
        message: 'Incorrect password.'
      )
    done null, user

)

###*
 * GitHub Auth
###

passport.use new GitHubStrategy(
  clientID: env.GITHUB_CLIENT_ID
  clientSecret: env.GITHUB_CLIENT_SECRET
  callbackURL: env.SERVER_ADDRESS + '/auth/github/callback'
, (accessToken, refreshToken, profile, done) ->
  User.findOrCreate
    githubId: profile.id
  , (err, user) ->
    done err, user

)

###*
 * Facebook Auth
###

passport.use new FacebookStrategy(
  clientID: env.FACEBOOK_APP_ID
  clientSecret: env.FACEBOOK_APP_SECRET
  callbackURL: env.SERVER_ADDRESS + '/auth/facebook/callback'
, (accessToken, refreshToken, profile, done) ->
  User.findOrCreate "bob", (err, user) ->
    return done(err)  if err
    done null, user
)

###*
 * Twitter Auth
###

passport.use new TwitterStrategy(
  consumerKey: env.TWITTER_CONSUMER_KEY
  consumerSecret: env.TWITTER_CONSUMER_SECRET
  callbackURL: env.SERVER_ADDRESS + "/auth/twitter/callback"
, (token, tokenSecret, profile, done) ->
  User.findOrCreate "bob", (err, user) ->
    return done(err)  if err
    done null, user

)

###*
 * Exports
###

module.exports = passport
