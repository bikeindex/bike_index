class BikeIndex.LandingPage extends BikeIndex
  constructor: ->
    # Instantiate stickyfill with offset of the header-nav
    $('.next-steps-wrap').css('top', "#{$('.primary-header-nav').outerHeight()}px")
    # Affix the edit menu to the page
    $('.next-steps-wrap').Stickyfill()