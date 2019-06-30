module.exports.Error404 = class Error404 extends Error
  name: 'Error404'
  constructor: ->
    super ...arguments
    @value = 404
    @message = 'Not Found'
