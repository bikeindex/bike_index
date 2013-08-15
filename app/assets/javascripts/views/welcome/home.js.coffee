class BikeIndex.Views.Home extends Backbone.View
  initialize: ->
    @setElement($('#body'))
    @moveBike()

  moveBike: ->
    register = $('#treating-right .treating-right-text')
    $(window).scroll -> 
      ww = $(window).width()
      aEnd = $('#fight-theft-profit').offset().top
      scroll = $(window).scrollTop()
      unless scroll >= aEnd
        p = ((scroll)/aEnd)
        spin = p * 50
        spin = spin * 2 if ww < 900 # When the screen is smaller, spin more, move less 
        $('#wheel-spin').css('-webkit-transform', "rotate(-#{spin}deg)")
        $('#wheel-spin').css('-moz-transform', "rotate(-#{spin}deg)")
        $('#wheel-spin').css('-o-transform', "rotate(-#{spin}deg)")
        
        # register.css('top', "#{p*25}px") # Small parallax on the button
     