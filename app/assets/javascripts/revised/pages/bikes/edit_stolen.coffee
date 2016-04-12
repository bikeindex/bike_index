class BikeIndex.BikesEditStolen extends BikeIndex
  constructor: ->
    @initializeEventListeners()

  initializeEventListeners: ->
    pagespace = @
    $('#mark-bike-stolen-btn').click (e) ->
      pagespace.markBikeStolen(e)

  markBikeStolen: (e) ->
    e.preventDefault()
    $('#bike_stolen').val('true')
    $('form.edit_bike').submit()