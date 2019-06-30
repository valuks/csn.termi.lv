exports.get = (subconfigs = ['local'])->
  c =
    development: false

    port: 9064
    db: 'mysql://root@127.0.0.1/csncomlv'
    support:
      email: ''
      pass: ''
      report: 'termilv@gmail.com'
      name: '[csn.termi.lv]'
    article_lifetime: 30
    article_per_page: 10
    google_analytics: 'UA-2332534-18'
    lang:
      title: 'Tematiskie uzdevumi ceļu satiksmes noteikumos'
      description: 'Tematiskie uzdevumi ceļu satiksmes noteikumos'
      description_category: (category)-> """#{category} kategorijai tematiskie uzdevumi ceļu satiksmes noteikumos"""
      footer: ''
      previous: 'iepriekšējā lapa'
      next: 'nākošā lapa'
      page: 'lapa'
      date: (d)->
        n = (v)-> "#{if v < 10 then "0" else ''}#{v}"
        [d.getFullYear(), n(d.getMonth() + 1), n(d.getDate())].join('.')
    error:
      404:
        title: '404 kļūda'
        description: """
          Lapa nav atrasta. Ej <a href="/">uz sākumu</a>.
        """
    static: [
      {
        url: '/'
        description: """
      <h1>Tematiskie uzdevumi ceļu satiksmes noteikumos</h1>
      <p>Jautājumi ņemti no <u>csnt.csdd.lv</u> un pie katra jautājuma ir datums (apzīmē jautājuma svaigumu).</p>
      <p>Izvēlieties pa kreisi vēlamo kategoriju.</p>
      <p>Pareizā atbilde iedegsies, ja uzspiedīsiet uz jautājuma atbildēm.</p>

        """
      }
    ]

  for subconfig in subconfigs
    for key, value of require("./config.#{subconfig}")
      c[key] = if typeof value is 'object' then Object.assign(c[key], value) else value
  c
