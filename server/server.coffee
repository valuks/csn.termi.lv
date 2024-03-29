config = require('../config').get()
express = require('express')
body_parser = require('body-parser')
_ = require('lodash')
pjson = require('../package.json')
Mysql = require('./helpers/mysql').Mysql
email = require('./helpers/email')
Template = require('./helpers/template').Template
Data = require('./helpers/data').Data
Error404 = require('./helpers/errors').Error404

email.config(config.support)
db = new Mysql(config.db)





app = express()
app.use(body_parser.urlencoded({
  extended: true
}))

if config.development
  server = require('./helpers/server_dev').init(app, express, config)
else
  process.on 'uncaughtException', (err)->
    console.info err
    email.log err
  server = app.listen(config.port)

App = {
  template: new Template({dirname: __dirname})

  data: new Data({db, categories: [4, 6, 7]})

  try: (res, fn)->
    try
      fn()
    catch e
      if e instanceof Error404
        return res.status(404).send(App.template.error('404'))
      res.status(500).send(App.template.error('500'))
      throw e
}


App.data._load =>
  console.log 'mysql data loaded'

  App.template.load_block('sidebar', App.data.sidebar())

  app.get ["/:category", "/:category/:page(\\d+)"], (req, res)->
    App.try res, ->
      res.send App.template.index App.data.category(req.params.category, parseInt(req.params.page or 1))

  config['static'].forEach (page)=>
    app.get "#{page.url}", (req, res)->
      res.send App.template.static(page)

  app.get '*', (req, res)->
    res.status(404).send(App.template.error('404'))

  reload = =>
    setTimeout =>
      App.data._load =>
        reload()
    , 1000 * 60 * 30
  reload()

console.log("http://127.0.0.1:#{config.port}/ version: #{pjson.version} #{if config.development then ' in development mode'}")
