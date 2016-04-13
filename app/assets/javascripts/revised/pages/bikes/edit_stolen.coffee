class BikeIndex.BikesEditStolen extends BikeIndex
  constructor: ->
    @initializeEventListeners()

  initializeEventListeners: ->
    pagespace = @
    $('#mark-stolen-btn').click (e) ->
      pagespace.markStolen(e)
    $('#toggle-stolen form').submit (e) ->
      e.preventDefault()
      pagespace.markRecovered()

  markStolen: (e) ->
    e.preventDefault()
    $('#bike_stolen').val('true')
    window.pageScript.submitBikeEditForm()

  recoveredRequestCallback: (message, success) ->
    $('#toggle-stolen').modal('hide')
    if success
      console.log 'IN SUCCESS'
      # BikeIndex.alertMessage('success', 'Bike marked recovered', "Thanks! We're so glad you got your bike back!")
      $('#bike_stolen').prop('checked', '')
      window.pageScript.submitBikeEditForm()
    else
      # BikeIndex.alertMessage('error', 'Request failed', "Oh no! Something went wrong and we couldn't mark your bike recovered.")

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
