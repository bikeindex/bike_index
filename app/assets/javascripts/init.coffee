# Ensure we have string trim
unless String::trim then String::trim = -> @replace /^\s+|\s+$/g, ""

# All the classes inherit from this
class window.BikeIndex

# This file initializes scripts for the application
class BikeIndex.Init extends BikeIndex
  constructor: ->
    new BikeIndex.NavHeader
    @loadFancySelects()
    @initializeNoTabLinks()
    @initializeScrollToRef()
    window.BikeIndexAlerts = new window.Alerts
    # Put this last, so if it fails, we still have some functionality
    @loadPageScript(document.getElementsByTagName('body')[0].id)
    # Initialize the js for the organized menu pages
    new BikeIndex.Organized if $('.organized-body').length > 0
    # Set the local timezone and convert all the times to local
    @localizeTimes()

  loadPageScript: (body_id) ->
    # If this is a landing page
    if body_id.match 'landing_pages_'
      return window.pageScript = new BikeIndex.LandingPage
    # All the rest per-page javascripts
    pageClasses =
      welcome_index: BikeIndex.WelcomeIndex
      info_where: BikeIndex.InfoWhere
      info_support_bike_index: BikeIndex.Payments
      payments_new: BikeIndex.Payments
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

  initializeScrollToRef: ->
    $('.scroll-to-ref').click (e) ->
      e.preventDefault()
      $target = $(event.target)
      # specify an additional manual offset if you'd like
      offset = $target.attr('data-offset')
      if offset? then offset = parseInt(offset, 10)
      offset ||= -20
      $('body, html').animate(
        scrollTop: $($target.attr('href')).offset().top + offset, 'fast'
      )

  displayLocalDate: (time, preciseTime = false) ->
    # Ensure we return if it's a big future day
    if time < window.tomorrow
      if time > window.today
        return time.format("h:mma")
      else if time > window.yesterday
        return "Yesterday #{time.format('h:mma')}"
    if time.year() == moment().year()
      if preciseTime then time.format("MMM Do[,] h:mma") else time.format("MMM Do[,] ha")
    else
      if preciseTime then time.format("YYYY-MM-DD h:mma") else time.format("YYYY-MM-DD")

  localizeTimes: ->
    window.timezone ||= moment.tz.guess()
    moment.tz.setDefault(window.timezone)
    window.yesterday = moment().subtract(1, "day").startOf("day")
    window.today = moment().startOf("day")
    window.tomorrow = moment().endOf("day")
    # Update any hidden fields with current timezone
    $(".hiddenFieldTimezone").val(window.timezone)

    displayLocalDate = @displayLocalDate

    # Write local time
    $(".convertTime").each ->
      $this = $(this)
      $this.removeClass("convertTime")
      text = $this.text().trim()
      return unless text.length > 0
      time = moment(text, moment.ISO_8601)
      return unless time.isValid
      $this.text(displayLocalDate(time, $this.hasClass("preciseTime")))

    # Write timezone
    $(".convertTimezone").each ->
      $this = $(this)
      $this.text(moment().format("z"))
      $this.removeClass("convertTimezone")

    # Write local time in fields
    $(".dateInputUpdateZone").each ->
      $this = $(this)
      time = moment($this.attr("data-initialtime"), moment.ISO_8601)
      $this.val(time.format("YYYY-MM-DDTHH:mm")) # Format that at least Chrome expects for field

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

enableEscapeForModals = ->
  $('.modal').on 'show.bs.modal', ->
    $(window).on 'keyup', (e) ->
      return unless e.keyCode == 27 # Escape key
      $('.modal').modal('hide')
  # Remove keyup trigger, clean up after yourself
  $('.modal').on 'hide.bs.modal', ->
    $(window).off 'keyup'

window.updateSearchBikesHeaderLink = ->
  location = localStorage.getItem('location')
  if location?
    location = location.replace(/^\s*|\s*$/g, '')
    location = 'you' if location.length < 1 or location == 'null'
    localStorage.setItem('location', location)
  distance = localStorage.getItem('distance')
  if distance?
    distance = parseInt(distance, 10)
    if isNaN(distance)
      distance = null
    else
      localStorage.setItem('distance', distance)
  distance ||= 100
  url = "/bikes?stolenness=proximity&location=#{location}&distance=#{distance}"
  $('#search_bikes_header_link').attr('href', url)

$(document).ready ->
  window.updateSearchBikesHeaderLink()
  window.BikeIndex.Init = new BikeIndex.Init
  if document.getElementById('binx_registration_widget')
    new window.ManufacturersSelect('#binx_registration_widget #b_param_manufacturer_id')
  new window.AdDisplayer
  warnIfUnsupportedBrowser()
  enableEscapeForModals()
