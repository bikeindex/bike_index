class BikeIndex.Views.Home extends Backbone.View
  events:
    'click .play-button': 'movieShowtime'

  initialize: ->
    @setElement($('#body'))
    @moveBike()
    @setMovieSize()
    that = @
    $( window ).resize ->
      that.setMovieSize()

  setMovieSize: ->
    height = $(window).width()*.66
    if height > $(window).height()
      height = $(window).height()
    $('#movie-cover .cover-container')
      .css('min-height', height)
      .css('max-height', height)
    

  movieShowtime: (event) ->
    event.preventDefault()
    $('#movie-cover').addClass('showing-movie')
    height = "100%"
    height = $(window).height() if $(window).width() < 768
    video = """<iframe width="100%" height="#{height}" src="//www.youtube.com/embed/wXucyGWF_rE?rel=0&autoplay=1" frameborder="0" allowfullscreen></iframe>"""
    setTimeout ( ->
      $('#iframe-holder')
        .addClass('showing-movie')
        .append(video)
    ) , 1000

  moveBike: ->
    register = $('#treating-right .treating-right-text')
    wheight = $(window).height()
    $(window).scroll -> 
      best = $('#best-ever').offset().top
      scroll = $(window).scrollTop()
      if (scroll/best) < .05
        $('#wheel-spin').removeClass('wheelspun')
      else
        unless $('#wheel-spin').hasClass('wheelspun')
          $('#wheel-spin').addClass('wheelspun')

        if (wheight*.7 + scroll) < best
          # if (wheight + scroll) < $('#best-ever article:first-of-type').offset().top
          $('#best-ever').addClass('displayno-icos') unless $('#best-ever').hasClass('displayno-icos')
        else
          $('#best-ever').removeClass('displayno-icos') if $('#best-ever').hasClass('displayno-icos')
        