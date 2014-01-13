class BikeIndex.Views.DocumentationIndex extends Backbone.View

  events:
    'click #documentation-menu a': 'scrollToMenuTarget'


  initialize: ->
    @setElement($('#body'))
    @manufacturerCall()
    # @createBike()
    @wheelSizeCall()
    # $('#body').attr('data-spy', "scroll").attr('data-target', '#documentation-menu')
    # $('#body').scrollspy(offset: - scroll_height)
    # $('#body').attr('data-spy', "scroll").attr('data-target', '#edit-menu')
    # $('#body').scrollspy(offset: - scroll_height)
    # $('#clearing_span').css('height', $('#edit-menu').height() + 25)
    # $('#edit-menu').attr('data-spy', 'affix').attr('data-offset-top', (menu_height-25))

  scrollToMenuTarget: (event) ->
    event.preventDefault()
    target = $(event.target).attr('href')
    $('body').animate( 
      scrollTop: ($(target).offset().top - 20), 'fast' 
    )
  
  manufacturerCall: ->
    $.ajax({
      type: "GET"
      url: $('#manufacturers-index').attr('data-url')
      success: (data, textStatus, jqXHR) ->
        $('#manufacturers-index').text(JSON.stringify(data,undefined,2))

      error: (data, textStatus, jqXHR) ->
        console.log(data)
      })
    $.ajax({
      type: "GET"
      url: $('#manufacturers-query').attr('data-url')
      success: (data, textStatus, jqXHR) ->
        $('#manufacturers-query').text(JSON.stringify(data,undefined,2))
      error: (data, textStatus, jqXHR) ->
        console.log(data)
      })

  wheelSizeCall: ->
    $.ajax({
      type: "GET"
      url: $('#wheel-sizes-index').attr('data-url')
      success: (data, textStatus, jqXHR) ->
        $('#wheel-sizes-index').text(JSON.stringify(data,undefined,2))
      error: (data, textStatus, jqXHR) ->
        console.log(data)
      })


  createBike: ->
    # token = '7fb1c38526e57a98ec57760aa7f84992'
    # org_slug = 'example-org'
    # url = "https://bikeindex.org/api/v1/bikes"
    
    # bikes_data = $('#bikes').data('bikes')

    # for bike_data in bikes_data

    # url = "http://lvh.me:3000/api/v1/bikes"
    # token = 'ea663d45d85169801f1dd90afc2178bc'
    # org_slug = 'blow-me'

      
    bike = 
      serial_number: "XOXO <3",
      manufacturer: "Surly",
      color: "Blue",
      rear_tire_narrow: false,
      rear_wheel_bsd: 559,
      description: "Has an under-seat beer opener and a handlebar flower vase",
      owner_email: "new_bike_owner@bikeindex.org"

    $.ajax
      url: $('#bike-standard').attr('data-url')
      type: "POST"
      data: 
        bike: bike
        organization_slug: $('#example_organization').attr('data-slug')
        access_token: $('#example_organization').attr('data-toke')
      success: (data, textStatus, jqXHR) ->
        $('#bike-standard').text(JSON.stringify(data,undefined,2))
        # console.log(jqXHR.responseText)
      error: (data, textStatus, jqXHR) ->
        $('#bike-standard').text(JSON.stringify(data,undefined,2))



      
  syntaxHighlight: (json) ->
    json = JSON.stringify(json, `undefined`, 2)  unless typeof json is "string"
    json = json.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    json.replace /("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g, (match) ->
      cls = "number"
      if /^"/.test(match)
        if /:$/.test(match)
          cls = "key"
        else
          cls = "string"
      else if /true|false/.test(match)
        cls = "boolean"
      else cls = "null"  if /null/.test(match)
      "<span class=\"" + cls + "\">" + match + "</span>"
