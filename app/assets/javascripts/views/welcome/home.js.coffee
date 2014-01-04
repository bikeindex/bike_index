class BikeIndex.Views.Home extends Backbone.View
  initialize: ->
    @setElement($('#body'))
    @moveBike()
    # @manufacturerCall()
    # @createBike()

  moveBike: ->
    register = $('#treating-right .treating-right-text')
    $(window).scroll -> 
      ww = $(window).width()
      aEnd = $('#fight-theft-profit').offset().top
      scroll = $(window).scrollTop()
      unless scroll >= aEnd
        p = ((scroll)/aEnd)
        spin = p * 50
        spin = spin * 1.5 if ww < 1200
        spin = spin * 1.5 if ww < 900 # When the screen is smaller, spin more, move less
        $('#wheel-spin').css('-webkit-transform', "rotate(-#{spin}deg)")
        $('#wheel-spin').css('-moz-transform', "rotate(-#{spin}deg)")
        $('#wheel-spin').css('-o-transform', "rotate(-#{spin}deg)")
        
        # register.css('top', "#{p*25}px") # Small parallax on the button


  manufacturerCall: ->
    $.ajax({
      type: "GET"
      url: 'https://www.bikeindex.org/api/v1/manufacturers'
      success: (data, textStatus, jqXHR) ->
        console.log("Response:  " + textStatus)
      error: (data, textStatus, jqXHR) ->
        console.log(data)
      })

  createBike: ->
    org_slug = 'ikes'

    bike = 
      serial_number: "69"
      cycle_type_id: 1
      manufacturer_id: 1
      rear_tire_narrow: false
      rear_wheel_size_id: 10
      primary_frame_color_id: 2
      owner_email: "seth@bikeindex.org"

    $.ajax
      # url: "https://bikeindex.org/api/v1/bikes"
      url: "http://lvh.me:3000/api/v1/bikes"
      type: "POST"
      data: { bike: bike, organization_slug: org_slug, access_token: token, keys_included: true }
      success: (data, textStatus, jqXHR) ->
        # console.log(data)
        console.log("Response:  " + textStatus)
        # console.log(jqXHR.responseText)

      error: (data, textStatus, jqXHR) ->
        console.log(jqXHR.responseText)
      