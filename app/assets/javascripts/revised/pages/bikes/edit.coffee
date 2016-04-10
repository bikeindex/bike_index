class BikeIndex.BikesEdit extends BikeIndex
  constructor: ->
    new BikeIndex.FormWell
    @initializeEventListeners()
    @initializeEditMenu()

  initializeEventListeners: ->
    pagespace = @
    $('#bike_unknown_year').change (e) ->
      pagespace.toggleUnknownYear()
    $('#bike_year').change (e) ->
      pagespace.updateYear()
    $('a.optional-form-block').click (e) ->
      new BikeIndex.OptionalFormUpdate(e)

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

  initializeEditMenu: ->
    # $target = $('.bike-edit-page-select')
    # c-select is added to style without JS, but fucks things up for selectize
    # $target.removeClass('c-select')
    # $('.bike-edit-page-select').selectize
    #   create: false
    #   maxItems: 1
    #   # selectOnTab: true
