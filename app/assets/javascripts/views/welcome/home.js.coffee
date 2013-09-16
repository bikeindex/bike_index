class BikeIndex.Views.Home extends Backbone.View
  initialize: ->
    @setElement($('#body'))
    @moveBike()
    @resizeVideo()

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
    wwidth = $(window).width()
    if wwidth > 720
      vwidth = 480
      vheight = 360
      if wwidth > 960  
        vwidth = 640
        vheight = 480
      video =  """
        <iframe width="#{vwidth}" height="#{vheight}" src="http://www.kickstarter.com/projects/1073266317/the-bike-index-lets-stop-bike-theft-together/widget/video.html" frameborder="0"> </iframe>
      """
      $('#kickstarter .kvid').append(video)
