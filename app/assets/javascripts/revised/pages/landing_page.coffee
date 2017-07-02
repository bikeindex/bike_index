class BikeIndex.LandingPage extends BikeIndex
  constructor: ->
    if $(window).width() > 767 # bootstrap md breakpoint
      # Instantiate stickyfill with offset of the header-nav
      header_offset = $('.primary-header-nav').outerHeight()
      $('.next-steps-wrap').css('top', "#{header_offset}px")
      # Affix the edit menu to the page
      $('.next-steps-wrap').Stickyfill()