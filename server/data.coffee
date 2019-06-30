class Data
  per_page: 10

  _load: (callback)->
    @_params = {}
    @_params.dbconnection = mysql.createConnection({
      host     : config.dbconnection.host or 'localhost'
      user     : config.dbconnection.user
      password : config.dbconnection.pass
      database : config.dbconnection.name
    })
    @_params.dbconnection.connect()
    @_load_images =>
      @_load_articles =>
        @_load_categories =>
          @_load_locations =>
            @_load_tags =>
              @_params.dbconnection.end()
              callback()

  _load_images: (callback)->
    images = {}
    @_params.dbconnection.query """
      SELECT
        a.`id`, a.`title`, a.`url`
      FROM
        `image` AS a
    """, (err, rows)=>
      if err
        throw err
      rows.forEach (image)=>
        image.url = '/i/' + image.url
        images[image.id] = image
      @_images = images
      callback()

  _load_articles: (callback)->
    articles = {}
    articles_index = []
    articles_starred = []
    articles_url = []
    vimeo_loading = 0
    vimeo_loaded = 0
    check = =>
      if vimeo_loading is vimeo_loaded
        @_articles = articles
        @_articles_index = articles_index
        @_articles_starred = articles_starred
        @_articles_url = articles_url
        callback()
    @_params.dbconnection.query """
SELECT
	a.`id`, a.`title`, a.`url`, a.`url_old`, a.`date`, a.`intro`, a.`full`, a.`starred`, a.`published`, a.`video`
    , im1.`url` AS img
    , im1.`title` AS img_title
    , im2.`url` AS img_sm
    , im2.`title` AS img_sm_title

    , (SELECT GROUP_CONCAT(`category_id`) FROM `article_category` WHERE `article_id`=a.`id`) AS `categories`
    , (SELECT GROUP_CONCAT(`tag_id`) FROM `article_tag` WHERE `article_id`=a.`id`) AS `tags`
    , (SELECT GROUP_CONCAT(`location_id`) FROM `article_location` WHERE `article_id`=a.`id`) AS `locations`
FROM
	`article` AS a
LEFT JOIN
	`image` AS im1
ON
	a.`img_id`=im1.`id`
LEFT JOIN
	`image` AS im2
ON
	a.`img_sm_id`=im2.`id`
ORDER BY
	a.`date` DESC, a.`id` DESC
      """, (err, rows)=>
      if err
        throw err
      rows.forEach (article)=>
        if article.img
          article.img = '/i/' + article.img
        if article.img_sm
          article.img_sm = '/i/' + article.img_sm
        video = @_parse_video(article.video)
        if video
          article.video = video[0]
          if !article.img and video[1][0]
            article.img = 'http://img.youtube.com/vi/' + video[1][0] + '/hqdefault.jpg'
          if !article.img_sm and video[1][0]
            article.img_sm = 'http://img.youtube.com/vi/' + video[1][0] + '/mqdefault.jpg'
          if video[2][0]
            vimeo_loading++
            request.get 'http://vimeo.com/api/v2/video/' + video[2][0] + '.json', (error, response, body)=>
              if error or response.statusCode isnt 200
                return
              data = JSON.parse(body)
              if !article.img_sm
                articles[article.id].img_sm = data[0].thumbnail_medium
              if !article.img
                articles[article.id].img = data[0].thumbnail_large
              vimeo_loaded++
              if vimeo_loading is vimeo_loaded
                check()
        article.categories = if not article.categories then [] else article.categories.split(',').map (c)-> parseInt(c)
        article.tags = if not article.tags then [] else article.tags.split(',').map (c)-> parseInt(c)
        article.locations = if not article.locations then [] else article.locations.split(',').map (c)-> parseInt(c)
        article.full = @_parse_content(article.full)
        articles[article.id] = article
        if article.published
          articles_index.push(article.id)
        if article.published and article.starred and articles_starred.length < 5
          articles_starred.push(article.id)
        articles_url[article.url] = article.id
      check()

  _load_categories: (callback)->
    categories = {}
    categories_url = {}
    @_params.dbconnection.query """
SELECT
	a.`id`, a.`title`, a.`url`
    , (SELECT GROUP_CONCAT(`article_id`) FROM `article_category` WHERE `category_id`=a.`id`) AS `articles`
FROM
	`category` AS a
ORDER BY
	a.`order` ASC, a.`id` ASC
      """, (err, rows)=>
      if err
        throw err
      rows.forEach (category)=>
        category.articles = if !category.articles then [] else _.intersection(@_articles_index, category.articles.split(',').map (c)-> parseInt(c) )
        categories[category.id] = category
        categories_url[category.url] = category.id
      @_categories = categories
      @_categories_url = categories_url
      callback()

  _load_tags: (callback)->
    tags = {}
    tags_url = {}
    @_params.dbconnection.query """
SELECT
	a.`id`, a.`title`, a.`url`
    , (SELECT GROUP_CONCAT(`article_id`) FROM `article_tag` WHERE `tag_id`=a.`id`) AS `articles`
FROM
	`tag` AS a
ORDER BY
	a.`order` ASC, a.`id` ASC
      """, (err, rows)=>
      if err
        throw err
      rows.forEach (tag)=>
        tag.articles = if !tag.articles then [] else _.intersection(@_articles_index, tag.articles.split(',').map (c)-> parseInt(c) )
        tags[tag.id] = tag
        tags_url[tag.url] = tag.id
      @_tags = tags
      @_tags_url = tags_url
      callback()

  _load_locations: (callback)->
    locations = {}
    locations_url = {}
    @_params.dbconnection.query """
SELECT
	a.`id`, a.`title`, a.`url`, a.`parent`
    , (SELECT GROUP_CONCAT(`article_id`) FROM `article_location` WHERE `location_id`=a.`id`) AS `articles`
FROM
	`location` AS a
ORDER BY
	a.`parent` ASC, a.`order` ASC, a.`id` ASC
      """, (err, rows)=>
      if err
        throw err
      rows.forEach (location)=>
        location.articles = if !location.articles then [] else _.intersection(@_articles_index, location.articles.split(',').map (c)-> parseInt(c) )
        locations[location.id] = location
        locations_url[location.url] = location.id
        if location.parent
          locations[location.parent].articles = _.intersection(@_articles_index, locations[location.parent].articles.concat(location.articles))
      @_locations = locations
      @_locations_url = locations_url
      callback()

  sidebar: ->
    {
      categories: _.orderBy _.values(@_categories), (o)-> o.order
      locations: _.orderBy _.values( _.filter(@_locations, (o)-> !o.parent ) ), (o)-> o.order
      lang: config.lang
    }

  starred: ->
    {
      articles: @_articles_starred.map (id)=> _.pick(@_articles[id], ['title', 'url', 'img_sm', 'img_sm_title'])
    }

  _location_list: (ar, params = ['title', 'url'])->
    _.flatten ar.map (id)=>
      ob = [_.pick(@_locations[id], params)]
      if @_locations[id].parent
        return @_location_list([@_locations[id].parent], params).concat(ob)
      ob

  _articles_list: (ar)->
    ar.map (id)=>
      article = _.pick(@_articles[id], ['title', 'date', 'url', 'intro', 'img', 'img_title', 'video'])
      article.intro = article.intro.replace("\n", "<br />\n")
      article

  list: (ids = @_articles_index, page)->
    pages = Math.ceil(ids.length / @per_page)
    if page < 1 or page > pages
      throw new Error404
    {
      page: {
        total: pages
        active: page
      }
      articles: @_articles_list(ids.slice((page - 1) * @per_page, page * @per_page))
      url: ''
      title: ''
      description: ''
      image: ''
    }

  category: (url, page)->
    id = @_categories_url[url]
    if !id
      throw new Error404
    _.extend @list(@_categories[id].articles, page), {
      url: "/#{config.lang.category}/#{url}"
      title: @_categories[id].title
      description: config.lang.description_category(@_categories[id].title)
    }

  tag: (url, page)->
    id = @_tags_url[url]
    if !id
      throw new Error404
    _.extend @list(@_tags[id].articles, page), {
      url: "/#{config.lang.tag}/#{url}"
      title: @_tags[id].title
      description: config.lang.description_tag(@_tags[id].title)
    }

  location: (url, page)->
    id = @_locations_url[url]
    if !id
      throw new Error404
    _.extend @list(@_locations[id].articles, page), {
      url: "/#{config.lang.location}/#{url}"
      title: @_locations[id].title
      description: config.lang.description_location(@_locations[id].title)
    }

  article: (url, published=true)->
    if !@_articles_url[url]
      throw new Error404
    if !@_articles[@_articles_url[url]].published and published
      throw new Error404
    {
      url: "/#{url}"
      title: @_articles[@_articles_url[url]].title
      description: @_articles[@_articles_url[url]].intro
      image: @_articles[@_articles_url[url]].img
      article: @_articles[@_articles_url[url]]
      tags: @_articles[@_articles_url[url]].tags.map (t)=> _.pick(@_tags[t], ['title', 'url'])
      locations: @_location_list(@_articles[@_articles_url[url]].locations)
    }

  _parse_paragraph: (str)->
    str.replace(/[\r\n]+/g, "\n").trim().split("\n").map (block)->
      block = block.trim()
      if block is '&nbsp;'
        return ''
      if block.substr(0, 1) is '<' and ['<em', '<st', '<im', '<a ', '<i>'].indexOf(block.substr(0, 3)) is -1
        return block
      return '<p>' + block + '</p>'
    .join("\n")

  _parse_video: (v)->
    if not v
      return v
    ids_youtube = []
    ids_vimeo = []
    v = v.replace /https\:\/\/www\.youtube\.com\/watch\?v=([^#\&\?\s]*)/g, (link, id)->
      ids_youtube.push(id)
      '<div class="video"><iframe width="560" height="349" src="http://www.youtube.com/embed/' + id + '?rel=0&hd=1" frameborder="0" allowfullscreen></iframe></div>'
    .replace /https\:\/\/vimeo\.com\/(\d+)/g, (link, id)->
      ids_vimeo.push(id)
      '<div class="video"><iframe width="560" height="349" src="//player.vimeo.com/video/' + id + '" frameborder="0" allowfullscreen></iframe></div>'
    [v, ids_youtube, ids_vimeo]

  _parse_infogram: (str)->
    infogram = []
    str = str.replace /https\:\/\/infogr\.am\/([^#\&\?\s]*)/g, (link, id)->
      infogram.push(id)
      '<div class="infogram-embed" data-id="' + id + '" data-type="interactive"></div>'
    if infogram.length is 0
      return str
    return str + "\n" + ("""

<script>!function (e, t, n, s) {
    var i = "InfogramEmbeds", o = e.getElementsByTagName(t), d = o[0], a = /^http:/.test(e.location) ? "http:" : "https:";
    if (s.substr(0, 2) === '//' && (s = a + s), window[i] && window[i].initialized) {
      window[i].process && window[i].process();
    } else if (!e.getElementById(n)) {
        var r = e.createElement(t);
        r.async = 1, r.id = n, r.src = s, d.parentNode.insertBefore(r, d)
    }
}(document, "script", "infogram-async", "//e.infogr.am/js/dist/embed-loader-min.js");</script>

      """.split("\n").join(' '))

  _parse_instagram: (str)->
    ids = []
    str = str.replace /https\:\/\/www\.instagram\.com\/p\/([^#\&\?\s]*)/g, (link, id)->
      ids.push(id)
      '<blockquote class="instagram-media" data-instgrm-version="2" style=" background:#000000; border:0; border-radius:3px; box-shadow:0 0 1px 0 rgba(0,0,0,0.5),0 1px 10px 0 rgba(0,0,0,0.15); margin: 1px; max-width:658px; padding:0; width:99.375%; width:-webkit-calc(100% - 2px); width:calc(100% - 2px);"><div style="padding:8px;"><div style=" background:#000000; line-height:0; margin-top:40px; padding-bottom:55%; padding-top:45%; text-align:center; width:100%;"><div style="position:relative;"><div style=" -webkit-animation:dkaXkpbBxI 1s ease-out infinite; animation:dkaXkpbBxI 1s ease-out infinite; background:url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACwAAAAsCAMAAAApWqozAAAAGFBMVEUiIiI9PT0eHh4gIB4hIBkcHBwcHBwcHBydr+JQAAAACHRSTlMABA4YHyQsM5jtaMwAAADfSURBVDjL7ZVBEgMhCAQBAf//42xcNbpAqakcM0ftUmFAAIBE81IqBJdS3lS6zs3bIpB9WED3YYXFPmHRfT8sgyrCP1x8uEUxLMzNWElFOYCV6mHWWwMzdPEKHlhLw7NWJqkHc4uIZphavDzA2JPzUDsBZziNae2S6owH8xPmX8G7zzgKEOPUoYHvGz1TBCxMkd3kwNVbU0gKHkx+iZILf77IofhrY1nYFnB/lQPb79drWOyJVa/DAvg9B/rLB4cC+Nqgdz/TvBbBnr6GBReqn/nRmDgaQEej7WhonozjF+Y2I/fZou/qAAAAAElFTkSuQmCC); display:block; height:44px; margin:0 auto -44px; position:relative; top:-44px; width:44px;"></div><span style=" color:#c9c8cd; font-family:Arial,sans-serif; font-size:12px; font-style:normal; font-weight:bold; position:relative; top:15px;">Loading</span></div></div><p style=" line-height:32px; margin-bottom:0; margin-top:8px; padding:0; text-align:center;"> <a href="https://www.instagram.com/p/' + id + '" style=" color:#c9c8cd; font-family:Arial,sans-serif; font-size:14px; font-style:normal; font-weight:normal; text-decoration:none;" target="_top"> View on Instagram</a></p></div><style>@-webkit-keyframes"dkaXkpbBxI"{ 0%{opacity:0.5;} 50%{opacity:1;} 100%{opacity:0.5;} } @keyframes"dkaXkpbBxI"{ 0%{opacity:0.5;} 50%{opacity:1;} 100%{opacity:0.5;} }</style></blockquote>'
    if ids.length is 0
      return str
    return str + '<script async defer src="//platform.instagram.com/en_US/embeds.js"></script>'

  _parse_links: (str)->
    @_parse_instagram(@_parse_infogram(str))

  _parse_content: (str)->
    if !str
      return ''
    @_parse_paragraph _.template( @_parse_links( @_parse_video(str)[0] ) )({
      img: (id)=>
        if !@_images[id]
          return "<img src=\"/d/images/dummy-700x400.png\" />"
        "<img src=\"#{@_images[id].url}\" alt=\"#{@_images[id].title}\" title=\"#{@_images[id].title}\" />"
    })
