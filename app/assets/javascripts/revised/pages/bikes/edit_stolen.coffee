class BikeIndex.BikesEditStolen extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    if $('.date_stolen_input').length > 0
      @initializeDateSelector()
      united_stated_id = $('#stolen_record_us_id').data('usid')
      new BikeIndex.ToggleHiddenOther('.country-select-input', united_stated_id)

  initializeEventListeners: ->
    $('#mark-stolen-btn').click (e) =>
      @markStolen(e)
    $('#toggle-stolen form').submit (e) =>
      e.preventDefault()
      @markRecovered()

  initializeDateSelector: ->
    new Pikaday(
      field: $('.date_stolen_input')[0]
      format: 'MM-DD-YYYY'
    )

  markStolen: (e) ->
    e.preventDefault()
    $('#bike_stolen').val('true')
    window.pageScript.submitBikeEditForm()

  recoveredRequestCallback: (message, success) ->
    if success
      msg = "Thanks for telling us! We're so glad you got your bike back!"
      $('#bike_stolen').prop('checked', '0')
      window.BikeIndexAlerts.add('success', msg, window.pageScript.submitBikeEditForm)
    else
      msg = "Oh no! Something went wrong and we couldn't mark your bike recovered."
      window.BikeIndexAlerts.add('error', msg)

  markRecovered: () ->
    $('#primary_stolen_phone_field input').attr('required', false)
    reason = $('#mark_recovered_reason').val()
    bike_id = $('#mark_recovered_bike_id').val()
    did_we_help = $('#mark_recovered_we_helped').prop('checked')
    can_share_recovery = $('#mark_recovered_can_share_recovery').prop('checked')
    if reason.length > 0 && bike_id.length > 0
      data = 
        request_type: 'bike_recovery'
        request_bike_id: bike_id
        request_reason: reason
        index_helped_recovery: did_we_help
        can_share_recovery: can_share_recovery
      response_callback = @recoveredRequestCallback
      new BikeIndex.SubmitUserRequest(data, response_callback)
    else
      $('#toggle-stolen .alert').slideDown('fast').removeClass('currently-hidden')
