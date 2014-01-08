class BikeIndex.Views.Home extends Backbone.View
  initialize: ->
    @setElement($('#body'))
    @moveBike()
    @manufacturerCall()
    @createBike()

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
    
    # org_slug = 'bikeindex'
    # url = "https://bikeindex.org/api/v1/bikes"
    
    url = "http://lvh.me:3000/api/v1/bikes"
    token = 'ea663d45d85169801f1dd90afc2178bc'
    org_slug = 'blow-me'

    bike = 
      serial_number: "69"
      manufacturer: "Surly"
      color: "Burgondy"
      rear_tire_narrow: false
      rear_wheel_bsd: 559
      description: "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod\ntempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
      owner_email: "seth@bikeindex.org"

    $.ajax
      url: url
      type: "POST"
      data: { bike: bike, organization_slug: org_slug, access_token: token, keys_included: true }
      success: (data, textStatus, jqXHR) ->
        console.log(data)
        console.log(data.responseText)
        console.log("Response:  " + textStatus)
        # console.log(jqXHR.responseText)

      error: (data, textStatus, jqXHR) ->
        console.log(jqXHR.responseText)
        console.log(data.responseText)
      