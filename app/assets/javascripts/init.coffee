# This file initializes scripts for the application
class window.BikeIndex
  pageLoad: ->
    new BikeIndex.NavHeader
    @loadFancySelects()
    @initializeNoTabLinks()
    window.BikeIndexAlerts = new BikeIndex.Alerts
    # Put this last, so if it fails, we still have some functionality
    @loadPageScript(document.getElementsByTagName('body')[0].id)
    

  loadPageScript: (body_id) ->
    # All the per-page javascripts
    pageClasses =
      info_where: BikeIndex.InfoWhere
      info_support_the_index: BikeIndex.InfoSupportTheIndex
      bikes_new: BikeIndex.BikesNew
      bikes_create: BikeIndex.BikesNew
      bikes_edit: BikeIndex.BikesEdit
      bikes_update: BikeIndex.BikesEdit
      bikes_show: BikeIndex.BikesShow
      bikes_index: BikeIndex.BikesIndex

    window.pageScript = new pageClasses[body_id] if Object.keys(pageClasses).includes(body_id)

  loadFancySelects: ->
    $('.unfancy.fancy-select select').selectize
      create: false
      plugins: ['restore_on_backspace']
    $('.unfancy.fancy-select-placeholder select').selectize # When empty options are allowed
      create: false
      plugins: ['restore_on_backspace', 'selectable_placeholder']
    # Remove them so we don't initialize twice
    $('.unfancy.fancy-select, .unfancy.fancy-select-placeholder').removeClass('unfancy')

  initializeNoTabLinks: ->
    # So in forms we can provide help without breaking tab index
    $('.no-tab').click (e) ->
      e.preventDefault()
      $target = $(e.target)
      local = $target.attr('data-target')
      if $target.hasClass('same-window')
        window.location = local
      else
        window.open(local, '_blank')

  # We need to call this because of Flexbox
  # Edge is fine, but all versions of IE are broken, and we should tell peeps
  msieversion = ->
    ua = window.navigator.userAgent
    msie = ua.indexOf('MSIE ')
    if msie > 0 or ! !navigator.userAgent.match(/Trident.*rv\:11\./)
      alert parseInt(ua.substring(msie + 5, ua.indexOf('.', msie)))
    else
      alert 'otherbrowser'
    false


$(document).ready ->
  window.BikeIndexInit = new window.BikeIndex
  window.BikeIndexInit.pageLoad()
