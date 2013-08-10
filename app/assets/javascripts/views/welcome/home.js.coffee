class BikeIndex.Views.Home extends Backbone.View
  initialize: ->
    @setElement($('#body'))
    @moveBike()

  moveBike: ->
    baseBlock = $('#fight-theft-profit')
    aBlock = $('#moving-block')
    $(window).scroll ->      
      sh = $(window).height()
      aStart = baseBlock.offset().top - sh + (baseBlock.height()*.92)
      aEnd = $('#best-ever').offset().top
      tScroll = baseBlock.height() + parseInt(baseBlock.css('padding-top')) + parseInt(baseBlock.css('padding-bottom'))
      scroll = $(window).scrollTop()
      if scroll >= aStart
        unless scroll >= aEnd
          p = ((scroll - aStart)/tScroll)
          aBlock.css('left', "#{p*150}%")
          aBlock.css('bottom', "#{40-(p*220)}px")
          aBlock.css('-webkit-transform', "rotate(#{(p*7)}deg)")
          aBlock.css('-moz-transform', "rotate(#{(p*7)}deg)")
          aBlock.css('-o-transform', "rotate(#{(p*7)}deg)")
          # -webkit-transform: rotate(-90deg);
          # -moz-transform: rotate(-90deg);
          # -o-transform: rotate(-90deg);
      if scroll < aStart
        unless scroll >= aEnd
          p = ((scroll)/tScroll)
          $('#wheel-spin').css('-webkit-transform', "rotate(-#{(p*30)}deg)")
          $('#wheel-spin').css('-moz-transform', "rotate(-#{(p*30)}deg)")
          $('#wheel-spin').css('-o-transform', "rotate(-#{(p*30)}deg)")
