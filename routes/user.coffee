nodemailer = require 'nodemailer'
bcrypt = require 'bcrypt'

gmail = nodemailer.createTransport "SMTP", {
  service: "Gmail",
  auth: {
    user: process.env.EMAIL_USERNAME
    pass: process.env.EMAIL_PASSWORD
  }
}

generateValidationCode = ->
  letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
  code = ""
  for i in [0..7]
    code += letters[Math.floor Math.random()*letters.length]
  return code

disallowedUsernameRegexps = [
  /master$/i
  /^admin/i
  /admin$/i
  /^(southackton|soha|somakeit|smi)$/i
  /^trust/i
  /^director/i
  /^(root|daemon|bin|sys|sync|backup|games|man|lp|mail|news|proxy|www-data|apache|apache2|irc|nobody|syslog|sshd|ubuntu|mysql|logcheck|redis)$/i
  /^(admin|join|social|info|queries)$/i
]

module.exports = (app) -> new class
  list: (req, response, next) ->
    query = "approved IS NOT NULL AND YEAR(approved) > 2012"
    if req.session.admin
      query = ""
    r = req.User.findAll(query)
    r.error (err) ->
      response.render 'message', {title:"Error", text: "Unknown error occurred, please try again later."}
    r.success (models) ->
      users = []
      for model in models
        user = model.toJSON()
        try
          user.data = JSON.parse user.data
        users.push user
      response.render 'users', {title: "User list", users:users}

  view: (req, response, next) ->
    id = req.params.userId
    r = req.User.find(id)
    r.error (err) ->
      response.render 'message', {title: "Error", text:"DB issue?"}
    r.success (user) ->
      render = (error) ->
        if !user
          return next()
        u = user.toJSON()
        try
          u.data = JSON.parse u.data
        catch e
          u.data = {}
        u.data.votes ?= []
        voted = (u.data.votes.indexOf(req.session.userId) isnt -1)
        response.render 'user', {title: user.fullname, user:u, voted: voted, error: error}
      if req.method is 'POST' and req.session.admin and req.body.form is 'approval'
        if req.body.reject is '1'
          gmail.sendMail {
            from: "So Make It <web@somakeit.org.uk>"
            to: user.email
            bcc: "#{process.env.TRUSTEES_ADDRESS}"
            subject: "So Make It application"
            text: """
              Hello #{user.fullname},

              Sorry to have to inform you that your application to join So Make It has been rejected.

              The person who reviewed your application was #{req.session.fullname}, and they gave the following reasons:

              ---
              #{req.body.message}
              ---

              Your account has been deleted from our server - please reapply once you've fixed the issues stated above.

              Kind regards,

              The So Make It web team.
              """
            }, (err, res) ->
              if err
                response.render 'message', {title: "Error", text: "Error sending email: #{err}"}
                return
              r = user.destroy()
              r.success ->
                user = null
                response.render 'message', {title: "User rejected", text: "Entry deleted from DB."}
              r.error (err) ->
                response.render 'message', {title: "Error", text: "Failed to delete user #{user.id} from the DB."}
        else if req.body.approve is '1'
          data = {}
          try
            data = JSON.parse user.data
          data.votes ?= []
          if data.votes.indexOf(req.session.userId) is -1
            data.votes.push req.session.userId
          if data.votes.length < app.locals.requiredVotes
            user.data = JSON.stringify data
            r = user.save()
            r.success ->
              render()
            r.error (err) ->
              response.render 'message', {title: "Error", text: "Failed to save user #{user.id} to the DB."}
          else
            # Approve
            gmail.sendMail {
              from: "So Make It <web@somakeit.org.uk>"
              to: user.email
              bcc: "#{process.env.TRUSTEES_ADDRESS}"
              subject: "So Make It approval"
              text: """
                Hello #{user.fullname} (#{user.username}),

                We're happy to inform you that your application to join So Make It was approved by #{req.session.fullname} and you are now on our Register of Members!

                Welcome! Why not read more about the makerspace on our wiki?

                http://wiki.somakeit.org.uk/

                Kind regards,

                The So Make It web team.
                """
              }, (err, res) ->
                if err
                  response.render 'message', {title: "Error", text: "Error sending email: #{err}"}
                  return
                delete data.votes
                user.data = JSON.stringify data
                user.approved = new Date()
                r = user.save()
                r.success ->
                  render()
                r.error (err) ->
                  response.render 'message', {title: "Error", text: "Failed to save user #{user.id} to the DB."}
        else
          render()
      else if req.method is 'POST' and req.session.admin and req.body.form is 'payment'
        {amount, duration, date, type} = req.body
        error = new Error()
        error.type = true if !type
        error.amount = true if !amount
        error.duration = true if !duration
        error.date = true if !date

        if type isnt 'CASH'
          error.type = true
          error.invalidType = type

        amount = parseInt(100*parseFloat(amount), 10)
        if amount < 500
          error.amount = true
          error.amountTooSmall = true

        duration = parseInt duration, 10
        if [1, 2, 3, 6, 12].indexOf(duration) is -1
          error.duration = true

        matches = date.match /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/
        if !matches
          error.date = true
          error.dateInvalid = true
        else
          [ignore, year, month, day] = matches
          year = parseInt year, 10
          month = parseInt month, 10
          day = parseInt day, 10
          now = new Date()
          if year > now.getFullYear()
            error.date = true
            error.invalidYear = true
          if year < now.getFullYear() - 1
            error.date = true
            error.invalidYear = true
          if [1..12].indexOf(month) is -1
            error.date = true
            error.invalidMonth = true
          if [1..31].indexOf(day) is -1
            error.date = true
            error.invalidDay = true

        if error.amount or error.duration or error.date or error.type
          return render(error)

        from = new Date()
        from.setFullYear year
        from.setMonth month - 1, day

        to = new Date(from.getTime())
        to.setMonth to.getMonth() + duration

        entry =
          user_id: user.id
          type: type
          amount: amount
          made: from
          subscription_from: from
          subscription_until: to
          data: JSON.stringify fromAdmin: true
        r = req.Payment.create entry
        r.success (payment) ->
          user.paid_until = to
          r = user.save()
          r.success ->
            render()
          r.error (err) ->
            console.error "Failed to update paid_until"
            console.error err
            response.render 'message', {title: "Error", text: "Failed to update user paid_until"}
        r.error (err) ->
          console.error "Failed to create payment"
          console.error err
          response.render 'message', {title: "Error", text: "Failed to create payment"}
      else
        render()

  auth: (req, response, next) ->
    response.locals.userId = null
    response.locals.loggedInUser = null
    loggedIn = ->
      console.log req.session
      response.locals.userId = req.session?.userId
      response.locals.fullname = req.session?.fullname
      response.locals.admin = req.session?.admin
      if req.session?.userId
        r = req.User.find(req.session.userId)
        r.error (err) ->
          return next()
        r.success (user) ->
          response.locals.loggedInUser = user
          return next()
      else
        return next()
    if req.session.userId? or ['/register', '/verify', '/forgot'].indexOf(req.path) isnt -1
      return loggedIn()
    render = (opts = {}) ->
      opts.err ?= null
      opts.data ?= {}
      opts.title = "Login"
      response.render 'login', opts
    if req.method is 'POST' and req.body.form is 'login' and req.body.email?
      # Check data
      {email, password} = req.body
      if email.match /@/
        query = where:{email:email}
      else
        query = where:{username:email}
      r = req.User.find(query)
      r.error (err) ->
        return render({data:req.body,err})
      r.success (user) ->
        if !user
          return render {data:req.body,err:new Error()}
        bcrypt.compare password, user.password, (err, res) ->
          if err or !res
            return render {data:req.body,err:new Error()}
          else
            if user.approved? and user.approved.getFullYear() > 2012
              req.session.userId = user.id
              req.session.fullname = user.fullname
              req.session.username = user.username
              req.session.admin = user.admin
              return loggedIn()
            else
              subject = "Pending approval: account ##{user.id}"
              response.render 'message',
                title:"Awaiting approval"
                html:
                  """
                  <p>
                  Our trustees need to enter you onto our Register of Members
                  before your account can be approved. If it's been more than 5
                  days, please contact <a
                  href="mailto:#{process.env.TRUSTEES_ADDRESS}?subject=#{encodeURIComponent
                  subject}">#{process.env.TRUSTEES_ADDRESS}</a>.
                  </p>
                  """
      return
    return render()

  verify: (req, response) ->
    {id, validationCode} = req.query ? {}
    id = parseInt(id, 10)
    validationCode = ""+validationCode
    fail = ->
      response.statusCode = 400
      response.render 'message', {title: "Invalid parameters", text: "Something went wrong - please check the email again."}
    success = ->
      response.render 'message', {title: "Validation complete", text: "Thanks! We'll be in touch shortly... "}
    if isNaN(id) or id <= 0 or validationCode.length isnt 8
      fail()
    else
      r = req.User.find(id)
      r.error (err) ->
        fail()
      r.success (user) ->
        if !user
          return fail()

        data = {}
        try
          data = JSON.parse user.data

        if !data.validationCode?
          success()
        else if data.validationCode is validationCode
          delete data.validationCode

          user.email = data.email ? user.email
          delete data.email
          delete data.validationCode
          user.data = JSON.stringify data

          r = user.save()
          r.error (err) ->
            console.error "Error saving validated user."
            console.error err
            response.render 'message', {title: "Database issue", text: "Please try again later."}
          r.success ->
            if user.approved? and user.approved.getFullYear() > 2012
              # XXX: email old address to tell them it has been replaced
              success()
            else
              approveURL = "#{process.env.SERVER_ADDRESS}/user/#{user.id}"
              gmail.sendMail {
                from: "So Make It <web@somakeit.org.uk>"
                to: process.env.APPROVAL_TEAM_EMAIL
                subject: "SoMakeIt[Registration]: #{user.fullname} (#{user.email})"
                body: """
                  New registration:

                    Email: #{user.email}
                    Username: #{user.username}
                    Name: #{user.fullname}
                    Address: #{("\n"+user.address).replace(/\n/g, "\n    ")}
                    Wiki: #{if user.wikiname then "http://wiki.somakeit.org.uk/wiki/User:#{user.wikiname}" else "nope"}

                  Approve or reject them here:
                  #{approveURL}

                  Thanks,

                  The So Make It web team
                  """
              }, (err, res) ->
                if err
                  console.error "Error sending notification to trustees"
                  console.error err
                success()
        else
          fail()

  forgot: (req, response) ->
    if req.session?.userId
      response.redirect "/"
      return
    render = (opts = {}) ->
      opts.err ?= null
      opts.data ?= {}
      opts.title = "Forgot Password"
      response.render 'forgot', opts
    success = ->
      response.render 'message', {title:"Success", text: "Password reset."}
    sent = ->
      response.render 'message', {title:"Password Reset Sent", text: "Please check your email for your reset code."}
    if req.method isnt 'POST'
      if req.query.id
        render({password:true})
      else
        render()
    else
      unless req.body.email? or req.query.id?
        return render()
      if req.query.id?
        id = parseInt(req.query.id, 10)
        r = req.User.find(id)
        r.error (err) ->
          response.render 'message', {title:"Error", text: "Unknown error occurred, please try again later."}
        r.success (user) ->
          if !user
            response.render 'message', {title:"Error", text: "User not found"}
            return
          data = {}
          try
            data = JSON.parse user.data
          if data.resetCode isnt req.query.validationCode or !data.resetCode or (data.passwordResetRequested ? 0) < (new Date().getTime() - 24*60*60*1000)
            response.render 'message', {title:"Denied", text: "Password reset expired."}
            return
          error = new Error()
          unless req.body.password?.length >= 6
            error.password = true
          unless req.body.password is req.body.password2
            error.password = true
            error.passwordsdontmatch = true
          if error.password
            render({password:true, err})
            return
          delete data.resetCode
          delete data.passwordResetRequested
          user.data = JSON.stringify data
          bcrypt.hash req.body.password, 10, (err, hash) ->
            if err or !hash
              response.render 'message', {title:"error", text: "unknown error occurred, please try again later."}
              return
            user.password = hash
            r = user.save()
            r.error (err) ->
              response.render 'message', {title:"error", text: "unknown error occurred, please try again later."}
            r.success ->
              success()

      else if req.body.email?
        r = req.User.find(where:{email:req.body.email})
        r.error (err) ->
          return render({data:req.body,err})
        r.success (user) ->
          if !user
            gmail.sendMail {
              from: "So Make It <web@somakeit.org.uk>"
              to: req.body.email
              subject: "So Make It reset"
              body: """
                Someone (hopefully you) attempted to reset the password for this
                account, however we don't have an account at this email address -
                sorry about that. Do you have any other addresses you may have
                used?

                Cheers,

                The So Make It web team.
                """
              }, (err, res) ->
                if err
                  response.render 'message', {title:"Error", text: "Failed to email you a password reset code. Sorry!"}
                  console.error err
                else
                  sent()
          else
            validationCode = generateValidationCode()
            data = {}
            try
              data = JSON.parse user.data
            data.resetCode = validationCode
            data.passwordResetRequested = new Date().getTime()
            user.data = JSON.stringify data
            r = user.save()
            r.error (err) ->

            verifyURL = "#{process.env.SERVER_ADDRESS}/forgot?id=#{user.id}&validationCode=#{validationCode}"
            r.success ->
              gmail.sendMail {
                from: "So Make It <web@somakeit.org.uk>"
                to: req.body.email
                subject: "So Make It password reset"
                body: """
                  Please click the link below to reset your password:

                  #{verifyURL}

                  Cheers,

                  The So Make It web team.
                  """
                }, (err, res) ->
                  sent()

  register: (req, response) ->
    if req.session?.userId
      response.redirect "/"
      return
    render = (opts = {}) ->
      opts.err ?= null
      opts.data ?= {}
      opts.title = "Register"
      response.render 'register', opts
    if req.method is 'POST' and req.body.form is 'register'
      error = new Error()
      unless /^[^@\s,"]+@[^@\s,]+\.[^@\s,]+$/.test req.body.email ? ""
        error.email = true
      unless /.+ .*/.test req.body.fullname ? ""
        error.fullname = true
      unless /^[a-z][a-z0-9]{2,13}$/i.test req.body.username ? ""
        error.username = true
      for regexp in disallowedUsernameRegexps when regexp.test req.body.username
        error.username = true
        error.username403 = true
      unless req.body.address?.length > 8
        error.address = true
      unless req.body.terms is 'on'
        error.terms = true
      unless req.body.password?.length >= 6
        error.password = true
      unless req.body.password is req.body.password2
        error.password = true
        error.passwordsdontmatch = true
      if error.email or error.fullname or error.address or error.terms or error.password or error.username
        render(err:error, data: req.body)
      else
        # Attempt registration
        validationCode = generateValidationCode()
        bcrypt.hash req.body.password, 10, (err, hash) ->
          if err
            return fail()
          r = req.User.create {
            email: req.body.email
            username: req.body.username
            password: hash
            fullname: req.body.fullname
            address: req.body.address
            wikiname: req.body.wikiname ? null
            data: JSON.stringify {
              email: req.body.email
              validationCode: validationCode
              registeredFromIP: req.ip
            }
          }
          r.success (user) ->
            # Send them the email
            verifyURL = "#{process.env.SERVER_ADDRESS}/verify?id=#{user.id}&validationCode=#{validationCode}"
            gmail.sendMail {
              from: "So Make It <web@somakeit.org.uk>"
              to: req.body.email
              subject: "SoMakeIt: verify your email address"
              body: """
                Hi #{req.body.fullname},

                Thanks for registering! Please verify your email address by clicking the link below:

                #{verifyURL}

                Thanks,

                The So Make It web team
                """
            }, (err, res) ->
              if err
                console.error "Error sending registration email."
                console.error err
                response.render 'message', {title:"Error", text: "Failed to email you the email verification code! Email web @ somakeit.org.uk"}
              else
                response.render 'registrationComplete', {title:"Registration complete", email: req.body.email, err: err}
          r.error (err) ->
            console.error "Error registering user:"
            console.error err
            if err.code is 'ER_DUP_ENTRY'
              if err.message.match /'email'/
                err.email = true
                err.email409 = true
              else
                err.username = true
                err.username409 = true
            else
              err.unknown = true
            render(err: err, data: req.body)
      return


    render()
