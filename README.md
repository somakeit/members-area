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
`npm install`

### Set up your environment
We use environmental variables to configure the software, but instead
you can create a `.env` file with `key=value` pairs. No comments, no
quotes, no nothing. Parsing is done by `env.coffee` if you want to
improve it.

Here's an example `.env` file:

```
SQLITE=1
SECRET=whateveryouwanthereitsnotimportant
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
