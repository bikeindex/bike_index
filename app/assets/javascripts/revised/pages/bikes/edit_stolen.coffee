# Runs on the following templates:
# bikes/edit_report_recovered
# bikes/edit_report_stolen


class BikeIndex.BikesEditStolen extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    if $('.stolenEditPage').length > 0
      united_states_id = $('#us_id_data').data('usid')
      new BikeIndex.ToggleHiddenOther('.country-select-input', united_states_id)

  initializeEventListeners: ->
    $('#toggle-stolen form').submit (e) =>
      e.preventDefault()
      # recoveredRequestCallback redirects once recovery succeeds. Redirecting here
      # would race a slow request, navigating away before the bike is recovered.
      @markRecovered()

  recoveredRequestCallback: (message, success) ->
    if success
      msg = "Thanks for telling us! We're so glad you got your bike back!"
      $('#bike_stolen').prop('checked', '0')
      redirect_url = window.location.href.replace(window.location.search, "")
      window.BikeIndexAlerts.add('success', msg, () -> window.location.href = redirect_url)
    else
      # Recovery failed - hide the spinner and restore the button so they can retry
      $('#mark_recovered_spinner').hide()
      $('#mark_recovered_action').show()
      msg = "Oh no! Something went wrong and we couldn't mark your bike recovered."
      window.BikeIndexAlerts.add('error', msg)

  markRecovered: () ->
    $('#primary_stolen_phone_field input').attr('required', false)
    reason = $('#mark_recovered_reason').val()
    bike_id = $('#mark_recovered_bike_id').val()
    did_we_help = $('#mark_recovered_we_helped').prop('checked')
    can_share_recovery = $('#mark_recovered_can_share_recovery').prop('checked')
    if reason.length > 0 && bike_id.length > 0
      # SubmitUserRequest hides the modal, so show the spinner on the page behind it
      # to signal the pending request until recoveredRequestCallback redirects
      $('#mark_recovered_action').hide()
      $('#mark_recovered_spinner').show()
      data =
        request_type: 'bike_recovery'
        request_bike_id: bike_id
        request_reason: reason
        index_helped_recovery: did_we_help
        can_share_recovery: can_share_recovery
      response_callback = @recoveredRequestCallback
      new BikeIndex.SubmitUserRequest(data, response_callback)
    else
      $("#toggle-stolen .alert").slideDown("fast").removeClass("currently-hidden")
