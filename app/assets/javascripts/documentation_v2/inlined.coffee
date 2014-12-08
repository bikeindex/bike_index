# This coffeescript is the js that is inlined on the swagger index page
$ ->
  addApiKeyAuthorization = ->
    key = $("#input_apiKey")[0].value
    log "key: " + key
    if key and key.trim() isnt ""
      log "added key " + key
      window.authorizations.add "access_token", new ApiKeyAuthorization("access_token", key, "query")
    return
  
  url = "#{window.base_url}/api/v2/swagger_doc"
  window.swaggerUi = new SwaggerUi(
    url: url
    dom_id: "swagger-ui-container"
    supportedSubmitMethods: [
      "get"
      "post"
      "put"
      "delete"
    ]
    onComplete: (swaggerApi, swaggerUi) ->
      # log "Loaded SwaggerUI"
      # if typeof initOAuth is "function"
      #   initOAuth
      #     clientId: "your-client-id"
      #     realm: "your-realms"
      #     appName: "your-app-name"

      $("pre code").each (i, e) ->
        hljs.highlightBlock e
        return

      return

    onFailure: (data) ->
      log "Unable to Load SwaggerUI"
      return

    docExpansion: "none"
    sorter: "alpha"
  )
  $("#input_apiKey").change ->
    addApiKeyAuthorization()
    return

  $('.set-token').click (e) ->
    e.preventDefault()
    $('body').animate( scrollTop: (0), 'fast' )
    $("#input_apiKey").val($(e.target).attr('data-token')).change()
  
  $('.newtoken-scope-check').change (e) ->
    app = $(e.target).parents('.application_list_box')
    link = app.find('.authorize_new_token_link')
    checked = app.find('.newtoken-scope-check input:checked')
    scopes = []
    scopes.push($(s).attr('id')) for s in checked   
    url = link.attr('data-base')
    url = "#{url}&scope=#{scopes.join('+')}" if scopes.length > 0
    link.attr('href', url).text(url)

  $('.add-token-form-btn').click (e) ->
    e.preventDefault()
    app = $(e.target).parents('.application_list_box')
    app_id = app.attr('data-id')
    app.find('.add-token-form, .add-token-form-btn').slideToggle()


  # if you have an apiKey you would like to pre-populate on the page for demonstration purposes...
  # apiKey = "68f00e0a1cec56d569facebb39aff7e033af49db234c1213901770fb10b39f30"
  # $("#input_apiKey").val apiKey
  # addApiKeyAuthorization()

  window.swaggerUi.load()
  
