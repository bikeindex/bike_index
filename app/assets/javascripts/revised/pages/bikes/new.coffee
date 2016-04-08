class BikeIndex.BikesNew extends BikeIndex
  constructor: ->
    new BikeIndex.ManufacturersSelect('#bike_manufacturer_id')
    @initializeEventListeners()

    if $('#bike_has_no_serial').prop('checked') == true
      $('#bike_serial_number').val('absent').addClass('absent-serial')
    @otherManufacturerDisplay($('#bike_manufacturer_id').val())

  initializeEventListeners: ->
    pagespace = @
    $('#bike_manufacturer_id').change (e) ->
      current_val = e.target.value
      pagespace.otherManufacturerDisplay(current_val)
      pagespace.getModelList(current_val)
    $('#bike_unknown_year').change (e) ->
      pagespace.toggleUnknownYear()
    $('#bike_year').change (e) ->
      pagespace.updateYear()
    $('a.optional-form-block').click (e) ->
      new BikeIndex.OptionalFormUpdate(e)

  otherManufacturerDisplay: (slug) ->
    hidden_other = $('#bike_manufacturer_id').parents('.related-fields').find('.hidden-other')
    if slug == 'other' # show the bugger!
      hidden_other.slideDown().addClass('unhidden')
    else if hidden_other.hasClass('unhidden') # Hide it!
      hidden_other.find('input').val('')
      hidden_other.removeClass('unhidden').slideUp()

  getModelList: (mnfg_name = '') ->
    pagespace = @
    if mnfg_name == 'absent' || mnfg_name.length < 1
      pagespace.setModelTypeahead()
    else
      year = parseInt($('#bike_year').val(),10)
      # could be bikebook.io - but then we'd have to pay for SSL...
      url = "https://bikebook.herokuapp.com/model_list/?manufacturer=#{mnfg_name}"
      url += "&year=#{year}" if year > 1
      $.ajax
        type: "GET"
        url: url
        success: (data, textStatus, jqXHR) ->
          pagespace.setModelTypeahead(data)
        error: ->
          pagespace.setModelTypeahead()

  setModelTypeahead: (data=[]) ->
    $('#bike_frame_model').selectize()[0].selectize.destroy()
    if data.length > 0
      window.m_data = data.map (i) -> { id: i }
      $('#bike_frame_model').selectize
        plugins: ['restore_on_backspace']
        options: data.map (i) -> { 'name': i }
        create: true
        maxItems: 1
        valueField: 'name'
        labelField: 'name'
        searchField: 'name'

  updateYear: ->
    if $('#bike_year').val()
      if $('#bike_year').val().length == 0
        $('#bike_year').selectize()[0].selectize.disable()
        $('#bike_unknown_year').prop('checked', true)
      else
        $('#bike_unknown_year').prop('checked', false)
    @getModelList($('#bike_manufacturer_id').val())

  toggleUnknownYear: ->
    year_select = $('#bike_year').selectize()[0].selectize
    if $('#bike_unknown_year').prop('checked')
      year_select.setValue('')
      year_select.disable()
    else
      year_select.setValue(new Date().getFullYear())
      year_select.enable()
