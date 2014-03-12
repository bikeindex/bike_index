class BikeIndex.Views.Home extends Backbone.View
  events:
    'click .play-button': 'movieShowtime'

  initialize: ->
    @setElement($('#body'))
    @moveBike()
    $('#movie-wrap').css('min-height',$(window).height()*.9 )


  movieShowtime: (event) ->
    event.preventDefault()
    $('#kickstarter').addClass('movie-showtime')
    setTimeout ( ->
      $('#iframe-holder')
        .addClass('showing-movie')
        # $('#movie-wrap .movie-container').css('min-height',$(window).height()*.9 )
        .append('<iframe width="100%" height="100%" src="//www.youtube.com/embed/wXucyGWF_rE?rel=0&autoplay=1" frameborder="0" allowfullscreen></iframe>')
    ) , 1000

  moveBike: ->
    register = $('#treating-right .treating-right-text')
    wheight = $(window).height()


    $(window).scroll -> 
      best = $('#best-ever').offset().top
      scroll = $(window).scrollTop()
      p = (scroll/best)
      if p < .05
        $('#wheel-spin').removeClass('wheelspun')
      else
        unless $('#wheel-spin').hasClass('wheelspun')
          $('#wheel-spin').addClass('wheelspun')

        if (wheight*.7 + scroll) < best
          # if (wheight + scroll) < $('#best-ever article:first-of-type').offset().top
          $('#best-ever').addClass('displayno-icos') unless $('#best-ever').hasClass('displayno-icos')
        else
          $('#best-ever').removeClass('displayno-icos') if $('#best-ever').hasClass('displayno-icos')
        