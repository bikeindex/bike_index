class BikeIndex.BikesEditRemove extends BikeIndex
  constructor: ->
    @initializeEventListeners()

  initializeEventListeners: ->
    $('#hide_bike_toggle').click (e) =>
      @toggleHidden(e)
    $('#request-delete form').submit (e) =>
      e.preventDefault()
      @requestDelete()
      # Safari blocks re-submission, FUCK THAT
      setTimeout (->
        $("#request-delete input[type=submit]").attr("disabled", false)
      ), 500

  toggleHidden: (e) ->
    e.preventDefault()
    $('#hide_bike_toggle_group input').val('true')
    window.pageScript.submitBikeEditForm()

  requestDeleteRequestCallback: (data, success) ->
    if success
      msg = "Your bike's been deleted!"
      window.BikeIndexAlerts.add('info', msg, () -> window.location.href = "/my_account")
    else
      msg = "Oh no! Something went wrong and we couldn't send the delete request."
      window.BikeIndexAlerts.add('error', msg)

  requestDelete: ->
    reason = $('#bike_delete_reason').val()
    bike_id = $('#bike_delete_bike_id').val()
    if reason.length > 0 && bike_id.length > 0
      data =
        request_type: 'bike_delete_request'
        request_bike_id: bike_id
        request_reason: reason
      response_callback = @requestDeleteRequestCallback
      new BikeIndex.SubmitUserRequest(data, response_callback)
    else
      $("#request-delete .alert").slideDown("fast").removeClass("currently-hidden")
