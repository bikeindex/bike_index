class BikeIndex.BikesNew extends BikeIndex
  constructor: ->
    new BikeIndex.ManufacturersSelect('#bike_manufacturer_id')
    new BikeIndex.FormWell
    @initializeEventListeners()
    @updateSerial($('#bike_has_no_serial').prop('checked'))
    @otherManufacturerDisplay($('#bike_manufacturer_id').val())
    if $('#stolen_record_us_id').length > 0
      united_stated_id = $('#stolen_record_us_id').data('usid')
      new BikeIndex.ToggleHiddenOther('.country-select-input', united_stated_id)

  initializeEventListeners: ->
    $('#bike_manufacturer_id').change (e) =>
      current_val = e.target.value
      @otherManufacturerDisplay(current_val)
      @getModelList(current_val)
    $('#bike_unknown_year').change (e) =>
      @toggleUnknownYear()
    $('#bike_year').change (e) =>
      @updateYear()
    $('#bike_has_no_serial').change (e) =>
      @updateSerial($('#bike_has_no_serial').prop('checked'))
    $('#made-without-serial-button').click (e) =>
      @madeWithoutSerial(true)
    $('#bike_made_without_serial').change (e) => # Only ever called when visible, so it's time to close
      @updateSerial(true)

  updateSerial: (serial_absent) ->
    @madeWithoutSerial()
    if serial_absent
      $('#bike_serial_number').val('absent').addClass('absent-serial')
      $('#made-without-serial-help .hidden-other').slideDown()
    else
      $('#bike_serial_number').val('').removeClass('absent-serial')
      $('#made-without-serial-help .hidden-other').slideUp()

  madeWithoutSerial: (no_serial = false) ->
    # Show the made_without_serial checkbox, hide other serial inputs
    $('#made-without-serial-modal').modal('hide')
    if no_serial
      $('#serial-input').slideUp()
      $('#made-without-serial-input').slideDown()
      $('#bike_made_without_serial').prop('checked', true)
    else
      $('#serial-input').slideDown()
      $('#made-without-serial-input').slideUp()
      $('#bike_made_without_serial').prop('checked', false)

  otherManufacturerDisplay: (slug) ->
    hidden_other = $('#bike_manufacturer_id').parents('.related-fields').find('.hidden-other')
    if slug == 'other' # show the bugger!
      hidden_other.slideDown().addClass('unhidden')
    else if hidden_other.hasClass('unhidden') # Hide it!
      hidden_other.find('input').val('')
      hidden_other.removeClass('unhidden').slideUp()

  getModelList: (mnfg_name = '') ->
    if mnfg_name == 'absent' || mnfg_name.length < 1
      @setModelTypeahead()
    else
      year = parseInt($('#bike_year').val(),10)
      # could be bikebook.io - but then we'd have to pay for SSL...
      url = "https://bikebook.herokuapp.com/model_list/?manufacturer=#{mnfg_name}"
      url += "&year=#{year}" if year > 1
      $.ajax
        type: "GET"
        url: url
        success: (data, textStatus, jqXHR) =>
          @setModelTypeahead(data)
        error: =>
          @setModelTypeahead()

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
