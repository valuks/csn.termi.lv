fs = require('fs')
_ = require('lodash')
pjson = require('../../package.json')
config = require('../../config').get()


module.exports.Template = class Template
  constructor: (@_params)->
    @_blocks = {}
    @_index = _.template(@read_template('index'))
    @_article_list = _.template(@read_template('article-list'))
    # @_article = _.template(@read_template('article'))
    @_static = _.template(@read_template('static'))
    @_error = _.template(@read_template('error'))
    @_params_default = {
      version: pjson.version
      lang: config.lang
      title: config.lang.title
      header: _.template(@read_template('blocks/header'), {imports: {
        links: config.static.map (link)-> _.pick(link, ['title', 'url'])
      }})
      footer: _.template(@read_template('blocks/footer'))({version: pjson.version, google_analytics: config.google_analytics, footer: config.lang.footer})
    }

  read_template: (name)->
    fs.readFileSync "#{@_params.dirname}/templates/#{name}.html"

  load_block: (block, params)->
    @_blocks[block] = ( (params)=>
      template = _.template(@read_template("blocks/#{block}"))
      (params2)=>
        template(Object.assign(params, params2))
    )(params)

  blocks: (blocks)->
    params = {}
    blocks.forEach (block)=>
      params[block] = @_blocks[block]
    params

  index: (params)->
    @_index(_.extend(@_params_default, @blocks(['sidebar']), params))

  error: (code)->
    @_error({error: config.error[code]})

  article_list: (params)->
    @_article_list(_.extend(@_params_default, @blocks(['sidebar']), params))

  # article: (params)->
  #   @_article(_.extend(@_params_default, @blocks(['sidebar']), params))

  static: (params)->
    @_static(_.extend(@_params_default, @blocks(['sidebar']), params))
