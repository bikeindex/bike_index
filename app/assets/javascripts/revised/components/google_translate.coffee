class BikeIndex.GoogleTranslate
  constructor: (sourceLang, targetLang) ->
    @baseUrl = "https://translate.googleapis.com"
    @sourceLang = sourceLang or I18n.defaultLocale
    @targetLang = targetLang or  I18n.locale

  translate: (text) ->
     path = "translate_a/single"
     query = [
       "client=gtx",
       "sl=#{@sourceLang}",
       "tl=#{@targetLang}",
       "dt=t",
       "q=#{encodeURI(text)}"
       ].join("&")

     fetch("#{@baseUrl}/#{path}?#{query}")
       .then((resp) => resp.json())
       .then((translations) => translations[0][0][0])
       .catch((err) => console.error(err))
