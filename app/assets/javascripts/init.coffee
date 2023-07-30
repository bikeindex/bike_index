# Ensure we have string trim
unless String::trim then String::trim = -> @replace /^\s+|\s+$/g, ""

# All the classes inherit from this
class window.BikeIndex
  loadFancySelects: ->
    $(".unfancy.fancy-select.no-restore-on-backspace select").selectize
      create: false
      selectOnTab: true
      plugins: []
      # TODO: Make it select on blur (select close) - but not change if there is already a value
      # onBlur: ->
      #   console.log(self.$activeItem)
      #   # console.log(self.getFirstItemMatchedByTextContent(value))
    $('.unfancy.fancy-select select').selectize
      create: false
      selectOnTab: true
      plugins: ['restore_on_backspace']
    $('.unfancy.fancy-select-placeholder select').selectize # When empty options are allowed
      create: false
      selectOnTab: true
      plugins: ['restore_on_backspace', 'selectable_placeholder']
    # Remove them so we don't initialize twice
    $('.unfancy.fancy-select, .unfancy.fancy-select-placeholder').removeClass('unfancy')

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
    @enableFullscreenOverflow()

  loadPageScript: (body_id) ->
    # If this is a landing page
    if body_id.match 'landing_pages_'
      return window.pageScript = new BikeIndex.LandingPage
    if body_id.match 'bikes_theft_alerts'
      return window.pageScript = new BikeIndex.BikesEdit

    # When save fails, it can render create or update (eg bikes_create) - but really, it's bikes_new
    # Make the body_id _new and _edit (rather than _create or _update)
    body_id = body_id.replace(/_create$/g, '_new').replace(/_update$/g, '_edit')

    # All the rest per-page javascripts
    pageClasses =
      welcome_index: BikeIndex.WelcomeIndex
      news_show: BikeIndex.WelcomeIndex # only used by get_your_stolen_bike back, this is a gross hack
      welcome_recovery_stories: BikeIndex.WelcomeRecoveryStories
      info_where: BikeIndex.InfoWhere
      info_donate: BikeIndex.Payments
      payments_new: BikeIndex.Payments
      bikes_new: BikeIndex.BikesNew
      bikes_edits_show: BikeIndex.BikesEdit
      bikes_edit: BikeIndex.BikesEdit # only happens from _update conversion
      bike_versions_edits_show: BikeIndex.BikesEdit
      bike_versions_edit: BikeIndex.BikesEdit
      bikes_show: BikeIndex.BikesShow
      bike_versions_show: BikeIndex.BikesShow
      bikes_index: BikeIndex.BikesIndex
      bike_versions_index: BikeIndex.BikesIndex
      organized_bikes_index: BikeIndex.BikesIndex
      orgpublic_impounded_bikes_index: BikeIndex.BikesIndex
      organized_graduated_notifications_index: BikeIndex.BikesIndex
      manufacturers_index: BikeIndex.InfoManufacturers
      my_accounts_edit: BikeIndex.UsersEdit
      users_new: BikeIndex.UsersNew
      my_account_show: BikeIndex.UserHome
      welcome_choose_registration: BikeIndex.ChooseRegistration
      stolen_index: BikeIndex.LegacyStolenIndex
      organized_manage_locations: BikeIndex.OrganizedManageLocations
      organizations_new: BikeIndex.OrganizedManageLocations # Because it has location fields
      organized_manage_show: BikeIndex.OrganizedManageLocations # it CAN location fields
      locks_new: BikeIndex.LocksForm
      locks_edit: BikeIndex.LocksForm
      stolen_bike_listings_index: BikeIndex.StolenBikeListing
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

  initializeScrollToRef: ->
    $('.scroll-to-ref').click (e) ->
      e.preventDefault()
      $target = $(event.target)
      # specify an additional manual offset if you'd like
      offset = $target.attr('data-offset')
      if offset? then offset = parseInt(offset, 10)
      offset ||= -80
      $('body, html').animate(
        scrollTop: $($target.attr('href')).offset().top + offset, 'fast'
      )
      history.replaceState({}, "", "#{location.pathname}#{$target.attr('href')}")

  displayLocalDate: (time, preciseTime, withPreposition) ->
    # Ensure we return if it's a big future day
    if time < window.tomorrow
      if time > window.today
        if withPreposition
          return "at #{time.format("h:mma")}"
        else
          return time.format("h:mma")
      else if time > window.yesterday
        return "Yesterday #{time.format('h:mma')}"
    if time.year() == moment().year()
      str = if preciseTime then time.format("MMM Do[,] h:mma") else time.format("MMM Do[,] ha")
    else
      str = if preciseTime then time.format("YYYY-MM-DD h:mma") else time.format("YYYY-MM-DD")
    if withPreposition then "on #{str}" else str

  localizeTimes: ->
    # NOTE: This uses time_parser-coffeeimport.js - not time_parser.js
    window.timeParser ||= new TimeParser()
    window.timeParser.localize()

  # copy of bike_index_utilities.js function
  enableFullscreenOverflow: ->
    pageWidth = $(window).width();
    $('.full-screen-table table').each (index) ->
      $this = $(this)
      if $this.outerWidth() > pageWidth
        $this.parents('.full-screen-table').addClass 'full-screen-table-overflown'


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
      $('.modal').modal('hide') if e.keyCode == 27 # Escape key
    $(".modal .close").on "click", (e) ->
      # potentially having trouble closing modals, try to fix it
      $(e.target).parents(".modal").modal("hide")
    return true
  # Remove keyup trigger, clean up after yourself
  $('.modal').on 'hide.bs.modal', ->
    $(window).off 'keyup'
    $(".modal .close").off

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

renderDonationModal = ->
  hideModal = localStorage.getItem("hideDonationModal")
  unless hideModal == "true"
    # Because caching, we set email in the template - so set it up now if possible
    email = $("#navUserSettingLink")?.attr("data-email")
    if email
      $("#new-payment-form #payment_email").val(email)
    $("#donationModal").modal("show")
    new BikeIndex.Payments
    # NOTE: This is also set in payments.coffee on payment submission
    $("#donationModal").on 'hide.bs.modal', ->
      localStorage.setItem("hideDonationModal", "true")

$(document).ready ->
  window.updateSearchBikesHeaderLink()
  enableEscapeForModals()
  window.BikeIndex.Init = new BikeIndex.Init
  if document.getElementById('binx_registration_widget')
    new window.ManufacturersSelect('#binx_registration_widget #b_param_manufacturer_id')
  warnIfUnsupportedBrowser()
  if $("#donationModal").length
    renderDonationModal()
  window.adDisplayer = new window.AdDisplayer
