New Version In Progress
=======================

There's a ground up rewrite of this Members Area in progress with many
more features, a plugin and theme architecture, roles and permissions
and much much more. The aim for the new Members Area is to be much
easier for other Makerspaces/Hackerspaces to customize and use for
their own purposes (not to mention making it easier to expand for So
Make It's usage).

The new version is temporarily located
[here](https://github.com/benjie/members-area) (it already has more
commits than this one!)

members-area
============

The code behind members.somakeit.org.uk

Running it locally
------------------

First make sure you're running at least v0.8 of Node.JS, and that you
have `npm` installed (you should - it's bundled with Node!). Then:

### Clone and enter directory
`git clone git@github.com:so-make-it/members-area.git && cd members-area`

### Install the members-area dependencies
```
npm install
npm install nodemon coffee-script mocha -g
```

### Set up your environment
We use environmental variables to configure the software, but instead
you can create a `.env` file with `key=value` pairs, no
quotes. Comments are a leading #. Parsing is done by `env.coffee` if you want to
improve it.

Here's an example `.env` file:

```
# force sqlite instead of mysql
SQLITE=1
SECRET=whateveryouwanthereitsnotimportant
CARD_SECRET=whateveryouwanthereitsnotimportant
EMAIL_USERNAME=yours@gmail.com
EMAIL_PASSWORD=yourpassword
APPROVAL_TEAM_EMAIL=yours+approval@gmail.com
TRUSTEES_ADDRESS=yours+trustees@gmail.com
SERVER_ADDRESS=http://localhost:1337
REQUIRED_VOTES=1
SORTCODE=00-00-00
ACCOUNTNUMBER=0000 0000
GOCARDLESS_ENVIRONMENT=sandbox
GOCARDLESS_APP_ID=
GOCARDLESS_APP_SECRET=
GOCARDLESS_MERCHANT=
GOCARDLESS_TOKEN=
FACEBOOK_ID=
FACEBOOK_SECRET=
GITHUB_ID=
GITHUB_SECRET=
TWITTER_KEY=
TWITTER_SECRET=
```

(Set `NODE_ENV` to `development` to get logging on the console/etc;
`./run` does this for you.)

### Setup the database

This will create a SQLite DB at `./db.sqlite` and apply the table models.

`coffee setup`

### Start the development server
`./run`

(Note: this has CoffeeScript compile everything to JavaScript with
source mapping support enabled, and then runs the JavaScript. When a
CoffeeScript file changes it will recompile to the relevant JavaScript
file which will cause the server to restart automatically.)

### Open your browser
To [http://localhost:1337](http://localhost:1337) and you should have it running :)

### Migrations

#### 0.2.0 > 0.3.0

Added social features thanks to [@bencevans][]; requires a minor DB
migration:

    ALTER TABLE Users ADD COLUMN facebookId INT;
    ALTER TABLE Users ADD COLUMN twitterId INT;
    ALTER TABLE Users ADD COLUMN githubId INT;


[@bencevans]: https://github.com/bencevans
