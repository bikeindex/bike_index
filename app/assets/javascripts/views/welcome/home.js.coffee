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
          p = ((scroll - aStart)/tScroll)*150
          aBlock.css('left', "#{p}%")




    

  centerHomeTitle: ->
    # This used to happen. Now it doesn't. Maybe sometime it will again?
    header = $('#header')
    header_height = header.height() + parseInt(header.css('padding-top')) + parseInt(header.css('padding-bottom'))
    screen_height = $(window).height()
    posit = (screen_height/2) - header_height
    $('#home-title').css('height', (screen_height - header_height - 280) ) # there are 60px of padding on the wrapper, show first line
    $('#home-title').css('min-height', '80px')
    $('#home-title h1').css('top', posit)

    # $('#home-title h1').css('padding-right', '30%')
    # shield_size = parseInt($('#home-title h1').css('padding-right'))
    # $('#shield-container').css('top', '25%').css('width', "#{shield_size * .9}px").css('height', "#{shield_size * .9}px").css('right', "#{shield_size * .1}px")

  intializeHomePage: ->
    @centerHomeTitle()
    # setTimeout ( ->
    #   $('#masonry-home').masonry({
    #     itemSelector: '.mason-box'
    #   })
    #   ), 500
    
    # Determine if the page has scrolled past the header
    bottom_stop = document.getElementById("faqLogo").scrollTop
    # console.log(bottom_stop)

    $(window).scroll ->
      total_scroll = $('#home-title').height()
      scroll = $(window).scrollTop()
      screen_width = $(window).width()
      switch_point = total_scroll/3

      unless scroll > total_scroll
        shield_size = parseInt($('#home-title h1').css('padding-right'))
        t_scroll = ($(window).scrollTop()/total_scroll)

        $('#shield-container').css('top', "#{25+t_scroll*55}%").css('width', "#{shield_size-t_scroll*100}px").css('height', "#{shield_size-t_scroll*100}px").css('right', "#{(shield_size * .1)*(1-t_scroll)}px")
        
        if scroll < switch_point
          $('#shield-container .bi-shield, #shield-container .axe1, #shield-container .axe2').css('opacity', 1)
          $('#shield-container .bi-logo').css('opacity', 0)
          # percentage of scroll to switch_point. We want a total rotation of 35 degrees. We want to move them up and down 10%
          scroll_percent = $(window).scrollTop()/switch_point
          
          $('#shield-container .axe2').css('-webkit-transform', "rotate(#{scroll_percent * 37}deg)").css('-moz-transform', "rotate(#{scroll_percent * 37}deg)").css('-ms-transform', "rotate(#{scroll_percent * 37}deg)").css('-o-transform', "rotate(#{scroll_percent * 37}deg)").css('transform', "rotate(#{scroll_percent * 37}deg)").css('top', "-#{scroll_percent * 10}%")
          $('#shield-container .axe1').css('-webkit-transform', "rotate(-#{scroll_percent * 37}deg)").css('-moz-transform', "rotate(-#{scroll_percent * 37}deg)").css('-ms-transform', "rotate(-#{scroll_percent * 37}deg)").css('-o-transform', "rotate(-#{scroll_percent * 37}deg)").css('transform', "rotate(-#{scroll_percent * 37}deg)").css('top', "#{scroll_percent * 10}%")

          
        else
          scroll_percent = ($(window).scrollTop() - switch_point)/(total_scroll-switch_point)
          
          $('#shield-container .bi-shield, #shield-container .axe1, #shield-container .axe2').css('opacity', 1 - scroll_percent)
          $('#shield-container .bi-logo').css('opacity', scroll_percent)

      # if $(window).scrollTop() > (headerHeight)
      #   $('#topsearch-tab').addClass('fixed')
      # else 
      #   $('#topsearch-tab').removeClass('fixed')
