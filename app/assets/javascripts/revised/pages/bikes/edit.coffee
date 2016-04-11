class BikeIndex.BikesEdit extends BikeIndex
  constructor: ->
    new BikeIndex.FormWell
    @initializeEventListeners()
    # Get the template name, call page specific Scripts if we have them
    switch $('#edit_page').attr('data-template')
      when 'root' then new BikeIndex.BikesEditRoot
      when 'wheels_drivetrain' then new BikeIndex.BikesEditWheelsDrivetrain

  initializeEventListeners: ->
    pagespace = @
    $('.bike-edit-page-select select').change (e) ->
      pagespace.updatePageLocation(this.value)

  updatePageLocation: (url) ->
    window.location.href = url