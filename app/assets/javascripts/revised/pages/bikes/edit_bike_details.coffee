class BikeIndex.BikesEditBikeDetails extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    new window.ManufacturersSelect('#manufacturer_update_manufacturer')
    @setFrameSize()
    @updateYear()

  initializeEventListeners: ->
    $('#bike_unknown_year').change (e) =>
      @toggleUnknownYear()
    $('#bike_year').change (e) =>
      @updateYear()
    $('#serial-correction form').submit (e) =>
      e.preventDefault()
      @requestSerialUpdate()
    $('#manufacturer-correction form').submit (e) =>
      e.preventDefault()
      @requestManufacturerUpdate()
    $('.frame-sizes .btn').click (e) =>
      @updateFrameSize(e)
    $('.toggle-version-date').click (e) =>
      @updateVersionDates(e)
    united_states_id = $('#us_id_data').data('usid')
    new BikeIndex.ToggleHiddenOther('.country-select-input', united_states_id)

  updateYear: ->
    return unless $('#bike_year').length
    if $('#bike_year').val().length == 0
      # $('#bike_year').selectize()[0].selectize.disable()
      $('#bike_unknown_year').prop('checked', true)
    else
      $('#bike_unknown_year').prop('checked', false)

  toggleUnknownYear: ->
    year_select = $('#bike_year').selectize()[0].selectize
    if $('#bike_unknown_year').prop('checked')
      year_select.setValue('')
      # year_select.disable()
    else
      year_select.setValue(new Date().getFullYear())
      # year_select.enable()

  setFrameSize: ->
    unit = $('#bike_frame_size_unit').val()
    if unit and unit != 'ordinal' and unit.length > 0
      $('.frame-size-other').slideDown().addClass('unhidden')
      $('.frame-size-units').addClass('ex-size')

  updateFrameSize: (e) ->
    size = $(e.target).attr('data-size')
    $hidden_other = $('.frame-size-other')
    if size == 'cm' or size == 'in'
      $('#bike_frame_size_unit').val(size)
      unless $hidden_other.hasClass('unhidden')
        $hidden_other.slideDown 'fast', ->
          $hidden_other.addClass('unhidden')
          $('.ordinal-sizes .btn').removeClass('active')
          $('.frame-sizes').removeClass('unexpanded-unit-size') # For small display setup. Remove space after appear
        $('#bike_frame_size').val('')
        $('#bike_frame_size_number').val('')
        $('.frame-size-units').addClass('ex-size')
    else
      $('#bike_frame_size_unit').val('ordinal')
      $('#bike_frame_size_number').val('')
      $('#bike_frame_size').val(size)
      $('.frame-sizes').addClass('unexpanded-unit-size') # For small display setup. Add space before collapse
      if $hidden_other.hasClass('unhidden')
        $hidden_other.slideUp 'fast', ->
          $hidden_other.removeClass('unhidden')
        $('.frame-size-units').removeClass('ex-size')
        $('.frame-size-units .btn').removeClass('active')

  requestSerialUpdateRequestCallback: (data, success) ->
    if success
      msg = "We've updated your serial!"
      window.BikeIndexAlerts.add('success', msg, window.pageScript.submitBikeEditForm)
    else
      window.BikeIndexAlerts.add('error', "We're unable to process the update! Try again?")

  requestManufacturerUpdateRequestCallback: (data, success) ->
    if success
      msg = "We've updated your manufacturer!"
      window.BikeIndexAlerts.add('success', msg, window.pageScript.submitBikeEditForm)
    else
      window.BikeIndexAlerts.add('error', "We're unable to process the update! Try again?")

  requestSerialUpdate: ->
    serial = $('#serial_update_serial').val()
    reason = $('#serial_update_reason').val()
    bike_id = $('#serial_update_bike_id').val()
    if serial.length > 0 && reason.length > 0 && bike_id.length > 0
      data =
        request_type: 'serial_update_request'
        request_bike_id: bike_id
        request_reason: reason
        serial_update_serial: serial
      response_callback = @requestSerialUpdateRequestCallback
      new BikeIndex.SubmitUserRequest(data, response_callback)
    else
      $('#serial-correction .alert').slideDown('fast')

  requestManufacturerUpdate: ->
    manufacturer = $('#manufacturer_update_manufacturer').val()
    reason = $('#manufacturer_update_reason').val()
    bike_id = $('#manufacturer_update_bike_id').val()
    if manufacturer.length > 0 && reason.length > 0 && bike_id.length > 0
      data =
        request_type: 'manufacturer_update_request'
        request_bike_id: bike_id
        request_reason: reason
        manufacturer_update_manufacturer: manufacturer
      response_callback = @requestManufacturerUpdateRequestCallback
      new BikeIndex.SubmitUserRequest(data, response_callback)
    else
      $('#manufacturer-correction .alert').slideDown('fast')

  updateVersionDates: (e) ->
    # Delay to let the fields populate
    window.setTimeout (->
      # Update the hidden fields
      start_at = $("#start-at").hasClass("unhidden")
      $('#bike_version_start_at_shown').val("#{start_at}")
      end_at = $("#end-at").hasClass("unhidden")
      $('#bike_version_end_at_shown').val("#{end_at}")
    ), 1000

