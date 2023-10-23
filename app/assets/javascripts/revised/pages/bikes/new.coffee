class BikeIndex.BikesNew extends BikeIndex
  constructor: ->
    new window.ManufacturersSelect('#bike_manufacturer_id')
    new BikeIndex.FormWell
    new window.CheckEmail('#bike_owner_email')
    @initializeEventListeners()
    @updateSerial($('#has_no_serial').prop('checked'))
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
    $('#has_no_serial').change (e) =>
      @updateSerial($('#has_no_serial').prop('checked'))
    $('#made-without-serial-button').click (e) =>
      @madeWithoutSerial(true)
    $('#bike_made_without_serial').change (e) => # Only ever called when visible, so it's time to close
      @updateSerial(true)
    $('#traditional_bike_checkbox').change (e) =>
      @updateCycleTypeCheck()
    $('#bike_cycle_type').change (e) =>
      @updatePropulsionType()
    $('#propulsion_type_motorized').change (e) =>
      @updatePropulsionType()

  updateSerial: (serial_absent) ->
    @madeWithoutSerial()
    if serial_absent
      serialVal = $("#bike_serial_number").val()
      unless serialVal == "made_without_serial" || serialVal == "unknown"
        window.existingSerialNumber = serialVal
      $('#bike_serial_number').val("unknown").addClass("absent-serial")
      $("#made-without-serial-help .hidden-other").slideDown()
    else
      if $("#bike_serial_number").val() == "unknown"
        $("#bike_serial_number").val(window.existingSerialNumber || "").removeClass("absent-serial")
      $("#made-without-serial-help .hidden-other").slideUp()

  madeWithoutSerial: (no_serial = false) ->
    # Show the made_without_serial checkbox, hide other serial inputs
    $('#made-without-serial-modal').modal('hide')
    if no_serial
      $("#serial-input, #made-without-serial-help, .made-without-serial-checkbox").slideUp()
      $('#made-without-serial-input').slideDown()
      $('#bike_made_without_serial').prop('checked', true)
      $('#bike_serial_number').val("made_without_serial")
    else
      $("#serial-input, #made-without-serial-help, .made-without-serial-checkbox").slideDown()
      $('#made-without-serial-input').slideUp()
      $('#bike_made_without_serial').prop('checked', false)

  otherManufacturerDisplay: (slug) ->
    hidden_other = $('#bike_manufacturer_id').parents('.related-fields').find('.hidden-other')
    if slug == 'other' or slug == 'Other' # show the bugger!
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

  updateCycleTypeCheck: ->
    $('#traditional_bike_checkbox').parents('label').collapse('hide')
    $('.cycle-type-select').collapse('show')

  # Set motorized if it should be motorized.
  # Only show propulsion type options if there can be options
  updatePropulsionType: ->
    cycleTypeValue = $('#bike_cycle_type').val()
    if window.cycleTypesAlwaysMotorized.includes(cycleTypeValue)
      $('#propulsionTypeFields').collapse('hide')
      $('#propulsion_type_motorized').prop('checked', true)
      $('#propulsion_type_motorized').attr('disabled', true)
      $('#motorizedWrapper').addClass('less-strong cursor-not-allowed').removeClass('cursor-pointer')
    else if window.cycleTypesNeverMotorized.includes(cycleTypeValue)
      $('#propulsion_type_motorized').prop('checked', false)
      $('#propulsion_type_motorized').attr('disabled', true)
      $('#propulsionTypeFields').collapse('hide')
      $('#motorizedWrapper').addClass('less-strong cursor-not-allowed').removeClass('cursor-pointer')
    else
      $('#motorizedWrapper').addClass('cursor-pointer').removeClass('less-strong cursor-not-allowed')
      $('#propulsion_type_motorized').attr('disabled', false)
      if $('#propulsion_type_motorized').prop('checked')
        if window.cycleTypesPedals.includes(cycleTypeValue)
          $('#propulsionTypeFields').collapse('show')
        else
          $('#propulsionTypeFields').collapse('hide')
      else
        $('#propulsionTypeFields').collapse('hide')

        $('#propulsion_type_throttle').prop('checked', false)
        $('#propulsion_type_pedal_assist').prop('checked', false)
