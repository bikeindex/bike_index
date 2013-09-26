class BikeIndex.Views.Home extends Backbone.View
  initialize: ->
    @setElement($('#body'))
    @moveBike()
    # @resizeVideo()
    # @manufacturerCall()

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

  resizeVideo: ->
    if $(window).width() > 960  
      vwidth = 640
      vheight = 480
      $('#kickstarter .kvid iframe').attr("width", vwidth).attr("height", vheight)


  manufacturerCall: ->
    $.ajax({
      type: "GET"
      url: 'https://www.bikeindex.org/api/v1/manufacturers'
      dataType: "jsonp",
      success: (data, textStatus, jqXHR) ->
        console.log(data)
      error: (data, textStatus, jqXHR) ->
        console.log(data)
      })
