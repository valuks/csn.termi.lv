pjson = require('../../package.json')
config = require('../../config').get()


module.exports.Data = class Data
  per_page: config.article_per_page
  constructor: (@options)->

  _load: (callback)->
    @_load_categories (categories)=>
      @_load_articles (articles)=>
        categories = categories.map (cat)->
          Object.assign cat, {
            articles: articles.filter (art)-> art.type_id is cat.id
          }
        @_categories_url = {}
        categories.forEach (cat, index)=> @_categories_url[cat.url] = index
        @_categories = categories
        # @_articles = articles
        callback()

  _load_categories: (callback)->
    @options.db.select {
      select: ['id', 'name', 'url']
      table: 'questions_type'
      order: ['id']
      where:
        id: @options.categories
    }, callback


  _load_articles: (callback)->
    @options.db.select {
      select: ['id', 'update', 'text', 'image', 'correct_id']
      table: 'questions_question'
      order: ['id']
      join:
        table: 'questions_question_types'
        select: ['type_id']
        on:
          id: 'question_id'
      where:
        published: 1
        'j.type_id': @options.categories
      # limit: 10000
      limit: 10
      sub:
        select: (row)->
          return {
            select: ['id', 'text']
            table: 'questions_answer'
            where:
              question_id: row.id
          }
    }, (data)=>
      data = data.filter (v, i)-> data.findIndex((v2)-> v2.id is v.id) is i
      callback(data)

  sidebar: ->
    {
      categories: @_categories.map (c)-> {id: c.id, name: c.name, url: c.url}
      lang: config.lang
    }

  _articles_list: (ar)->
    ar.map (article)=>
      Object.assign article, {
        # image: ''
      }

  list: (articles, page)->
    pages = Math.ceil(articles.length / @per_page)
    if page < 1 or page > pages
      throw new Error404
    {
      page: {
        total: pages
        active: page
      }
      articles: @_articles_list(articles.slice((page - 1) * @per_page, page * @per_page))
    }

  category: (url, page)->
    id = @_categories_url[url]
    if id < 0
      throw new Error404
    _.extend @list(@_categories[id].articles, page), {
      url: "/#{url}"
      title: @_categories[id].name
      category_active: id
      description: config.lang.description_category(@_categories[id].name)
    }
