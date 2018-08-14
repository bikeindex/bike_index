scrollToRef = (event) ->
  event.preventDefault()
  target = $(event.target).attr('href')
  window.scrollTo({
    top: $(target).offset().top - 90,
    behavior: 'smooth'
  })

waypointer = ->
  for l in $('#navmenu-fixed a')
    link = $(l)
    waypoints = $(link.attr('href')).waypoint handler: (direction) ->
      $('#navmenu-fixed a').removeClass('scrltrgt')
      $("#m_#{@element.id}").addClass('scrltrgt')
      return

operationsAfterSwaggerLoads = ->
  # delayed, runs after swagger is loaded (hopefully)
  $('select[name="test"]').val('true')
  waypointer() if $('#navmenu-fixed').is(':visible')


# This coffeescript is the js that is inlined on the swagger index page
$ ->
  addApiKeyAuthorization = ->
    key = $("#input_apiKey")[0].value
    log "key: " + key
    if key and key.trim() isnt ""
      log "added key " + key
      window.authorizations.add "access_token", new ApiKeyAuthorization("access_token", key, "query")
    return

  url = window.swagger_url
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
      token = localStorage.getItem('access_token')
      if token? && token.length > 0
        $("#input_apiKey").val(token).change()

      # if typeof initOAuth is "function"
      #   initOAuth
      #     clientId: "your-client-id"
      #     realm: "your-realms"
      #     appName: "your-app-name"

      $("pre code").each (i, e) ->
        hljs.highlightBlock e
        return

      $('td:contains(query_items)').parents('tr').hide()

    onFailure: (data) ->
      log "Unable to Load SwaggerUI"

    docExpansion: "list"
    sorter: "alpha"
  )

  $('.scroll-link, #navmenu-fixed a').click (e) ->
    scrollToRef(e)

  $("#input_apiKey").change ->
    addApiKeyAuthorization()
    localStorage.setItem('access_token', $('#input_apiKey').val())
    return

  $('.set-token').click (e) ->
    e.preventDefault()
    $('#header').addClass('headroom--pinned').removeClass('headroom--unpinned')
    input_key = $("#input_apiKey")
    input_key.fadeOut('fast', ->
      input_key.val($(e.target).attr('data-token')).change()
      input_key.fadeIn('fast')
    )


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

  $('.listed-app-name').click (e) ->
    e.preventDefault()
    target = $(e.target)
    target.parents('.application_list_box').find('.application-info').slideToggle('fast')
    target.toggleClass('uncollapsed')

  param_token = window.location.href.match(/access_token=[^#|\/]*/i)
  if param_token? && param_token.length > 0
    $("#input_apiKey").val(param_token[0].replace('access_token=', '')).change()

  window.swaggerUi.load()
  window.setTimeout (->
    operationsAfterSwaggerLoads()
  ), 2000
