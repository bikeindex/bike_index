class BikeIndex.Organized extends BikeIndex
  constructor: ->
    @setOrganizedWrapHeight()

    # Only on the edit organization page, but no real reason to create another
    # coffeescript file
    $('.avatar-upload-field').change (event) ->
      name = event.target.files[0].name
      $(event.target).parent().find('.file-upload-text').text(name)

  setOrganizedWrapHeight: ->
    min_px = $('.organized-menu-wrapper').outerHeight()
    $('.organized-wrap').css('min-height', "#{min_px + 24}px")