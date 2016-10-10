class BikeIndex.BikesEdit extends BikeIndex
  constructor: ->
    new BikeIndex.FormWell
    new FormWellMenu
    # Get the template name, call page specific Scripts if we have them
    switch $('.form-well-header.container').attr('data-template')
      when 'root' then new BikeIndex.BikesEditRoot
      when 'ownership' then new BikeIndex.BikesEditOwnership
      when 'drivetrain' then new BikeIndex.BikesEditDrivetrain
      when 'stolen' then new BikeIndex.BikesEditStolen
      when 'photos' then new BikeIndex.BikesEditPhotos
      when 'accessories' then new BikeIndex.BikesEditAccessories
      when 'remove' then new BikeIndex.BikesEditRemove

  updatePageLocation: (url) ->
    window.location.href = url

  submitBikeEditForm: ->
    $('form.primary-edit-bike-form').submit()
    setTimeout (-> # Sometimes the page reload isn't triggered. Do it manually
      location.reload(true)
    ), 300
