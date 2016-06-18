class BikeIndex.Organized extends BikeIndex
  constructor: ->
    @setOrganizedWrapHeight()

  setOrganizedWrapHeight: ->
    min_px = $('.organized-menu-wrapper').outerHeight()
    $('.organized-wrap').css('min-height', "#{min_px + 20}px")