class BikeIndex.BikesEditRoot extends BikeIndex
  constructor: ->
    @initializeEventListeners()

  initializeEventListeners: ->
    pagespace = @
    $('#bike_unknown_year').change (e) ->
      pagespace.toggleUnknownYear()
    $('#bike_year').change (e) ->
      pagespace.updateYear()

  updateYear: ->
    if $('#bike_year').val()
      if $('#bike_year').val().length == 0
        $('#bike_year').selectize()[0].selectize.disable()
        $('#bike_unknown_year').prop('checked', true)
      else
        $('#bike_unknown_year').prop('checked', false)

  toggleUnknownYear: ->
    year_select = $('#bike_year').selectize()[0].selectize
    if $('#bike_unknown_year').prop('checked')
      year_select.setValue('')
      year_select.disable()
    else
      year_select.setValue(new Date().getFullYear())
      year_select.enable()
