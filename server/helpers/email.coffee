emailjs = require('emailjs')

email = null

config = {}
module.exports.config = (c)->
  config = c
  email = emailjs.server.connect({
    user: config.email,
    password: config.pass,
    host: 'smtp.gmail.com',
    ssl: true
  })


module.exports.send = email_send = (params, callback=->)->
  email.send Object.assign({}, params, {
    subject: "#{config.name} #{params.subject}"
    from: "<#{config.email}>"
  }), (err)->
    if err
      console.log 'EMAIL ERROR', new Date(), err
    callback(err)


module.exports.send_admin = (params)-> email_send Object.assign({to: config.report}, params)


errors_log = []
module.exports.log = (err, _messages = [], callback=->)->
  errors_log.push(new Date().getTime())
  email_send {
    subject: (if err then ' server error: ' + err.message else '')
    text: ''
    to: config.report
    attachment: [{
      alternative:true
      data: """
        #{(if err then err.stack + ''+ '<br /><br />' else '')}
        <br />
        #{_messages.join("\n<br />")}
      """
    }]
  }, (err_email)->
    if err_email or 'ECONNREFUSED' is err.code
      console.info 'mail error', err_email
      process.exit(1)
    if errors_log.length > 2
      if errors_log[2] - errors_log[0] < 3 * 1000
        process.exit(1)
      errors_log.shift()
    callback(err)
