class BikeIndex.BikesEditOwnership extends BikeIndex
  constructor: ->
    @initializeEventListeners()

  initializeEventListeners: ->
    pagespace = @
    $('#hide_bike_toggle').click (e) ->
      pagespace.toggleBikeHidden(e)
    $('#request-bike-delete-btn').click (e) ->
      pagespace.requestBikeDelete(e)

  toggleBikeHidden: (e) ->
    e.preventDefault()
    $('#hide_bike_toggle_group input').val('true')
    $('form.edit_bike').submit()

  requestBikeDelete: (e) ->
    e.preventDefault()
    reason = $('#bike_delete_reason').val()
    bike_id = $('#bike_delete_bike_id').val()
    if reason.length > 0 && bike_id.length > 0
      url = $('#request-bike-delete').attr('data-url')
      $.ajax
        type: "POST"
        url: url
        data:
          request_type: 'bike_delete_request'
          request_bike_id: bike_id
          request_reason: reason
        success: (data, textStatus, jqXHR) ->
          # BikeIndex.alertMessage('success', 'Bike delete submitted', "Deleting your bike now. We delete all bikes by hand, it could take up to a day before your bike is gone. Thanks for your patience!")
        error: (data, textStatus, jqXHR) ->
          # BikeIndex.alertMessage('error', 'Request failed', "Oh no! Something went wrong and we couldn't send the delete request.")
      $('#request-bike-delete').modal('hide')
    else
      $('#request-bike-delete-error').slideDown('fast').removeClass('currently-hidden')