# All the classes inherit from this
class window.BikeIndex
  loadFancySelects: ->
    $('.unfancy.fancy-select select').selectize
      create: false
      plugins: ['restore_on_backspace']
    $('.unfancy.fancy-select-placeholder select').selectize # When empty options are allowed
      create: false
      plugins: ['restore_on_backspace', 'selectable_placeholder']
    # Remove them so we don't initialize twice
    $('.unfancy.fancy-select, .unfancy.fancy-select-placeholder').removeClass('unfancy')

# This file initializes scripts for the application
class BikeIndex.Init extends BikeIndex
  constructor: ->
    new BikeIndex.NavHeader
    @loadFancySelects()
    @initializeNoTabLinks()
    window.BikeIndexAlerts = new window.Alerts
    # Put this last, so if it fails, we still have some functionality
    @loadPageScript(document.getElementsByTagName('body')[0].id)
    # Initialize the js for the organized menu pages
    new BikeIndex.Organized if $('.organized-body').length > 0

  loadPageScript: (body_id) ->
    # All the per-page javascripts
    pageClasses =
      welcome_index: BikeIndex.WelcomeIndex
      info_where: BikeIndex.InfoWhere
      info_support_the_index: BikeIndex.InfoSupportTheIndex
      bikes_new: BikeIndex.BikesNew
      bikes_create: BikeIndex.BikesNew
      bikes_edit: BikeIndex.BikesEdit
      bikes_update: BikeIndex.BikesEdit
      bikes_show: BikeIndex.BikesShow
      bikes_index: BikeIndex.BikesIndex
      manufacturers_index: BikeIndex.InfoManufacturers
      users_edit: BikeIndex.UsersEdit
      welcome_user_home: BikeIndex.UserHome
      welcome_choose_registration: BikeIndex.ChooseRegistration
      stolen_index: BikeIndex.LegacyStolenIndex
      organized_manage_locations: BikeIndex.OrganizedManageLocations
      locks_new: BikeIndex.LocksForm
      locks_edit: BikeIndex.LocksForm
      locks_create: BikeIndex.LocksForm
    window.pageScript = new pageClasses[body_id] if Object.keys(pageClasses).includes(body_id)

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
  # msieversion: ->
  #   ua = window.navigator.userAgent
  #   msie = ua.indexOf('MSIE ')
  #   if msie > 0 or ! !navigator.userAgent.match(/Trident.*rv\:11\./)
  #     alert parseInt(ua.substring(msie + 5, ua.indexOf('.', msie)))


window.updateSearchBikesHeaderLink = ->
  location = localStorage.getItem('location')
  if location?
    location = location.replace(/^\s*|\s*$/g, '')
    location = 'you' if location.length < 1 or location == 'null'
    localStorage.setItem('location', location)
  url = "/bikes?stolen=true&proximity=#{location}"
  $('#search_bikes_header_link').attr('href', url)

$(document).ready ->
  window.updateSearchBikesHeaderLink()
  new BikeIndex.Init
  if document.getElementById('binx_registration_widget')
    new window.ManufacturersSelect('#binx_registration_widget #b_param_manufacturer_id')
  new window.AdDisplayer