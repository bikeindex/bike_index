class BikeIndex.BikesEditStolen extends BikeIndex
  constructor: ->
    @initializeEventListeners()

  initializeEventListeners: ->
    pagespace = @
    $('#mark-stolen-btn').click (e) ->
      pagespace.markStolen(e)
    $('#mark-recovered-btn').click (e) ->
      pagespace.markRecovered(e)

  markStolen: (e) ->
    e.preventDefault()
    $('#bike_stolen').val('true')
    $('form.edit_bike').submit()

  markRecovered: (e) ->
    e.preventDefault()
    $('#primary_stolen_phone_field input').attr('required', false)
    reason = $('#mark_recovered_reason').val()
    bike_id = $('#mark_recovered_bike_id').val()
    did_we_help = $('#mark_recovered_we_helped').prop('checked')
    can_share_recovery = $('#mark_recovered_can_share_recovery').prop('checked')
    if reason.length > 0 && bike_id.length > 0
      url = $('#toggle-stolen').attr('data-url')
      $.ajax
        type: "POST"
        url: url
        data:
          request_type: 'bike_recovery'
          request_bike_id: bike_id
          request_reason: reason
          index_helped_recovery: did_we_help
          can_share_recovery: can_share_recovery
        success: (data, textStatus, jqXHR) ->
          # BikeIndex.alertMessage('success', 'Bike marked recovered', "Thanks! We're so glad you got your bike back!")
          $('#toggle-stolen').modal('hide')  
          $('#bike_stolen').prop('checked', '')
          $('form.edit_bike').submit()
        error: (data, textStatus, jqXHR) ->
          # BikeIndex.alertMessage('error', 'Request failed', "Oh no! Something went wrong and we couldn't mark your bike recovered.")
      $('#toggle-stolen').modal('hide')
    else
      $('#toggle-stolen-error').slideDown('fast')
