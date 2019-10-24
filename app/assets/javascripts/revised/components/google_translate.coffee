class BikeIndex.GoogleTranslate
  constructor: (sourceLang, targetLang) ->
    @baseUrl = "https://translate.googleapis.com"
    @sourceLang = sourceLang or I18n.defaultLocale
    @targetLang = targetLang or  I18n.locale

  # Translate the provided text using the google translate chrome extension
  # endpoint. Targeting this endpoint will work for the welcome index and 2-3
  # pages of full recovery stories before triggering a rate limit.
  # Not ideal, but that should be plenty for our needs.
  #
  # Returns the translated text. If the request errors, return null.
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
       .catch((err) => null)
