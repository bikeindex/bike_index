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
      payments_new: BikeIndex.InfoSupportTheIndex
      bikes_new: BikeIndex.BikesNew
      bikes_create: BikeIndex.BikesNew
      bikes_edit: BikeIndex.BikesEdit
      bikes_update: BikeIndex.BikesEdit
      bikes_show: BikeIndex.BikesShow
      bikes_index: BikeIndex.BikesIndex
      organized_bikes_index: BikeIndex.BikesIndex
      manufacturers_index: BikeIndex.InfoManufacturers
      users_edit: BikeIndex.UsersEdit
      users_new: BikeIndex.UsersNew
      users_create: BikeIndex.UsersNew
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


# Check if the browser supports Flexbox
warnIfUnsupportedBrowser = ->
  d = document.documentElement.style
  unless 'flexWrap' of d or 'WebkitFlexWrap' of d or 'msFlexWrap' of d
    if $('#old-browser-warning').length < 1
      if navigator.appName == 'Microsoft Internet Explorer' or ! !(navigator.userAgent.match(/Trident/) or navigator.userAgent.match(/rv 11/)) or $.browser and $.browser.msie == 1
          header = 'Your browser (Internet Explorer) is is not supported'
      else
        header = 'Your browser is out of date!'
      $('body').prepend "<div id='old-browser-warning'><h4>#{header}</h4><p>As a result, Bike Index will not function correctly. <a href=\"http://whatbrowser.com\">Learn more here</a>.</p></div>"

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
  warnIfUnsupportedBrowser()