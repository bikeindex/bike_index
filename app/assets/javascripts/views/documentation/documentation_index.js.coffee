class BikeIndex.Views.DocumentationIndex extends Backbone.View
  initialize: ->
    @indexCall()
    @manufacturerCalls()
    @bikeSearchCall()
    production = parseInt($('#documentation_head').attr('data-production'), 10)
    unless production == 1
      @createBikes()
  
  manufacturerCalls: ->
    $.ajax
      type: "GET"
      url: $('#manufacturers_frame_makers').attr('data-url')
      success: (data, textStatus, jqXHR) ->
        $('#manufacturers_frame_makers').text(JSON.stringify(data,undefined,2))
      error: (data, textStatus, jqXHR) ->
        $('#manufacturers_frame_makers').text(JSON.stringify(data,undefined,2))
      
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
  
  indexCall: ->
    id_blocks = [
      '#wheel_sizes_index'
      '#cycle_types_index'
      '#frame_materials_index'
      '#handlebar_types_index'
      '#component_types_index'
    ]
    for id in id_blocks
      $.ajax
        type: "GET"
        url: $(id).attr('data-url')
        success: (data, textStatus, jqXHR) ->
          i = Object.keys(data)[0]
          $("##{i}_index").text(JSON.stringify(data,undefined,2))
        error: (data, textStatus, jqXHR) ->
          $("##{i}_index").text(data)

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
    photos = [
      "https://bikeindex.s3.amazonaws.com/uploads/Pu/545/large_8465603755_223358d8b4_b.jpg"
      "https://bikeindex.s3.amazonaws.com/uploads/Pu/544/large_8433449838_8660d50a08_b.jpg"
    ]
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