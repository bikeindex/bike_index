class BikeIndex.LandingPage extends BikeIndex
  constructor: ->
    # Only instantiate Stickyfill if window is larger than the breakpoint for switching
    # to the select menu on the bottom - Stickyfill doesn't do a good job with that
    if $(window).width() > 767 # bootstrap md breakpoint
      # Make things render
      $('.next-steps-wrap').css('top', "#{$('.primary-header-nav').outerHeight()}px")
      # Affix the edit menu to the page
      $('.next-steps-wrap').Stickyfill()