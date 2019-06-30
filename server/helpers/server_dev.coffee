module.exports.init = (app, express, config)->
  server = app.listen(config.port)
  app.use('/public', express.static(__dirname + '/../../public'))
  app.use('/bower_components', express.static(__dirname + '/../../bower_components'))
  app.use('/node_modules', express.static(__dirname + '/../../node_modules'))

  return server
