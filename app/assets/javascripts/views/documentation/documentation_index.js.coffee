class BikeIndex.Views.DocumentationIndex extends Backbone.View

  events:
    'click #documentation-menu a': 'scrollToMenuTarget'


  initialize: ->
    @setElement($('#body'))
    production = parseInt($('#documentation_head').attr('data-production'), 10)
    @manufacturerCall()
    @bikeSearchCall()
    @attributesCall()

    unless production == 1
      @createBikes()
      
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
    $.ajax
      type: "GET"
      url: $('#manufacturers_frame_makers').attr('data-url')
      success: (data, textStatus, jqXHR) ->
        $('#manufacturers_frame_makers').text(JSON.stringify(data,undefined,2))
      error: (data, textStatus, jqXHR) ->
        console.log(data)
      
    $.ajax
      type: "GET"
      url: $('#manufacturers_query').attr('data-url')
      success: (data, textStatus, jqXHR) ->
        $('#manufacturers_query').text(JSON.stringify(data,undefined,2))
      error: (data, textStatus, jqXHR) ->
        console.log(data)
  
  bikeSearchCall: ->
    $.ajax
      type: "GET"
      url: $("#bikes_search_query").attr('data-url')
      success: (data, textStatus, jqXHR) ->
        $("#bikes_search_query").text(JSON.stringify(data,undefined,2))
      error: (data, textStatus, jqXHR) ->
        $("#bikes_search_query").text(JSON.stringify(data,undefined,2))
  
  attributesCall: ->
    id_blocks = ['#wheel_sizes_index', '#cycle_types_index', '#frame_materials_index', '#handlebar_types_index', '#component_types_index']
    for id in id_blocks
      $.ajax
        type: "GET"
        url: $(id).attr('data-url')
        success: (data, textStatus, jqXHR) ->
          i = Object.keys(data)[0]
          $("##{i}_index").text(JSON.stringify(data,undefined,2))
        error: (data, textStatus, jqXHR) ->
          console.log(data)

  createBikes: ->      
    component_bike =
      serial_number: "XOXO :)"
      manufacturer: "WorkCycles"
      color: "Red"
      rear_wheel_bsd: 559
      rear_tire_narrow: false
      owner_email: "cargo_bike_owner@bikeindex.org"
      cycle_type_slug: "cargo"
      frame_material_slug: "steel"
      handlebar_type_slug: "flat"
      description: "Amazing cargo bike. Has made me car free!"
    components = [
      manufacturer: "SRAM"
      year: "2013"
      component_type: "crankset"
      description: "2X10 crankset"
      model_name: "X0"
    ,
      manufacturer: "SRAM"
      component_type: "bottom-bracket"
      model_name: "GXP team"
    ]

    $.ajax
      url: $('#bike_components').attr('data-url')
      type: "POST"
      data: 
        bike: component_bike
        components: components
        organization_slug: $('#example_organization').attr('data-slug')
        access_token: $('#example_organization').attr('data-token')
      success: (data, textStatus, jqXHR) ->
        $('#bike_components').text(JSON.stringify(data,undefined,2))
      error: (data, textStatus, jqXHR) ->
        $('#bike_components').text(JSON.stringify(data,undefined,2)) 
        
    bike = 
      serial_number: "XOXO <3"
      manufacturer: "Surly"
      color: "Blue"
      rear_tire_narrow: false
      rear_wheel_bsd: "559"
      owner_email: "new_bike_owner@bikeindex.org"
    
    $.ajax
      url: $('#bike_basic').attr('data-url')
      type: "POST"
      data: 
        bike: bike
        organization_slug: $('#example_organization').attr('data-slug')
        access_token: $('#example_organization').attr('data-token')
      success: (data, textStatus, jqXHR) ->
        $('#bike_basic').text(JSON.stringify(data,undefined,2))
        # console.log(jqXHR.responseText)
      error: (data, textStatus, jqXHR) ->
        $('#bike_basic').text(JSON.stringify(data,undefined,2))

    stolen_bike =
      stolen: true
      phone: "(124) 534-6339"
      serial_number: "XXXX :("
      manufacturer: "Jamis"
      color: "Black"
      rear_wheel_bsd: 559
      rear_tire_narrow: false
      owner_email: "stolen_bike_owner@bikeindex.org"

    stolen_record =
      date_stolen: "03-01-2013"
      theft_description: "This bike was stolen and that's no fair."
      country: "US"
      street: "Cortland and Ashland"
      city: "Chicago"
      zipcode: "60622"
      state: "IL"
      police_report_number: "99999999"
      police_report_department: "Chicago"

    $.ajax
      url: $('#bike_stolen').attr('data-url')
      type: "POST"
      data: 
        bike: stolen_bike
        stolen_record: stolen_record
        organization_slug: $('#example_organization').attr('data-slug')
        access_token: $('#example_organization').attr('data-token')
      success: (data, textStatus, jqXHR) ->
        $('#bike_stolen').text(JSON.stringify(data,undefined,2))
      error: (data, textStatus, jqXHR) ->
        $('#bike_stolen').text(JSON.stringify(data,undefined,2))       


      
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
