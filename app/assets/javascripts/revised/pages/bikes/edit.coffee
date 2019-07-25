class BikeIndex.BikesEdit extends BikeIndex
  constructor: ->
    new BikeIndex.FormWell
    new FormWellMenu
    # Get the template name, call page specific Scripts if we have them
    switch $('.form-well-header.container').attr('data-template')
      when 'bike_details' then new BikeIndex.BikesEditBikeDetails
      when 'drivetrain' then new BikeIndex.BikesEditDrivetrain
      when 'report_stolen' then new BikeIndex.BikesEditStolen
      when 'report_recovered' then new BikeIndex.BikesEditStolen
      when 'theft_details' then new BikeIndex.BikesEditStolen
      when 'photos' then new BikeIndex.BikesEditPhotos
      when 'accessories' then new BikeIndex.BikesEditAccessories
      when 'remove' then new BikeIndex.BikesEditRemove
      when 'groups' then new BikeIndex.BikesEditGroups
      when 'alert' then new BikeIndex.BikesEditAlert
      when 'alert_purchase' then new BikeIndex.BikesEditAlertPurchase

  updatePageLocation: (url) ->
    window.location.href = url

  submitBikeEditForm: ->
    $('form.primary-edit-bike-form').submit()
    setTimeout (-> # Sometimes the page reload isn't triggered. Do it manually
      location.reload(true)
    ), 300
