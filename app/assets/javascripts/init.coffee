# This file initializes scripts for the application
class window.BikeIndex
  pageLoad: ->
    new BikeIndex.NavHeader
    @loadFancySelects()
    window.BikeIndexAlerts = new BikeIndex.Alerts
    # Put this last, so if it fails, we still have some functionality
    @loadPageScript(document.getElementsByTagName('body')[0].id)
    

  loadPageScript: (body_id) ->
    # All the per-page javascripts
    pageClasses =
      info_about: BikeIndex.InfoAbout
      bikes_new: BikeIndex.BikesNew
      bikes_create: BikeIndex.BikesNew
      bikes_edit: BikeIndex.BikesEdit
      bikes_update: BikeIndex.BikesEdit

    window.pageScript = new pageClasses[body_id] if Object.keys(pageClasses).includes(body_id)

  loadFancySelects: ->
    $('.unfancy.fancy-select select').selectize
      create: false
      plugins: ['restore_on_backspace']
    $('.unfancy.fancy-select-placeholder select').selectize # When empty options are allowed
      create: false
      plugins: ['restore_on_backspace', 'selectable_placeholder']
    # Remove them so we don't initialize twice
    $('.special-select-single.unfancy').removeClass('unfancy')



$(document).ready ->
  bike_index = new window.BikeIndex
  bike_index.pageLoad()
