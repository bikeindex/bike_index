class BikeIndex.BikesEditRoot extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    new BikeIndex.ManufacturersSelect('#manufacturer_update_manufacturer')

  initializeEventListeners: ->
    pagespace = @
    $('#bike_unknown_year').change (e) ->
      pagespace.toggleUnknownYear()
    $('#bike_year').change (e) ->
      pagespace.updateYear()
    $('#serial-correction form').submit (e) ->
      e.preventDefault()
      pagespace.requestSerialUpdate()
    $('#manufacturer-correction form').submit (e) ->
      e.preventDefault()
      pagespace.requestManufacturerUpdate()

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

  requestSerialUpdateRequestCallback: (data, success) ->
    # BikeIndex.alertMessage('success', 'Serial correction submitted', "Processing your updated serial now. We review all updates by hand, it could take up to a day before your bike is updated. Thanks!")
    # BikeIndex.alertMessage('error', 'Request failed', "We're unable to process the update! Try again?")
    $('.modal.in').modal('hide')
    window.pageScript.submitBikeEditForm()

  requestManufacturerUpdateRequestCallback: (data, success) ->
    # BikeIndex.alertMessage('success', 'Manufacturer correction submitted', "Processing your updated Manufacturer now. We review all updates by hand, it could take up to a day before your bike is updated. Thanks!")
    # BikeIndex.alertMessage('error', 'Request failed', "We're unable to process the update! Try again?")
    $('.modal.in').modal('hide')
    window.pageScript.submitBikeEditForm()

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