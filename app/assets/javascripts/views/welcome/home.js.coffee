class BikeIndex.Views.Home extends Backbone.View
  initialize: ->
    @setElement($('#body'))
    @moveBike()

  moveBike: ->
    baseBlock = $('#fight-theft-profit')
    aBlock = $('#moving-block')
    $(window).scroll ->      
      sh = $(window).height()
      aStart = baseBlock.offset().top - sh + (baseBlock.height()/2)
      aEnd = $('#support-the-community').offset().top
      tScroll = baseBlock.height() + parseInt(baseBlock.css('padding-top')) + parseInt(baseBlock.css('padding-bottom'))
      scroll = $(window).scrollTop()
      if scroll >= aStart
        unless scroll >= aEnd
          p = ((scroll - aStart)/tScroll)
          aBlock.css('left', "#{p*150}%")
          aBlock.find('img').css('height', "#{100-(p*25)}%")
