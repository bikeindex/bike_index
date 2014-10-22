setModelTypeahead = (data=[]) ->
  autocomplete = $('#bike_frame_model').typeahead()
  autocomplete.data('typeahead').source = data 
  # $('#bike_frame_model').typeahead({source: data})

getModelList = ->
  mnfg = $('#bike_manufacturer_id option:selected').text()
  unless mnfg == "Choose manufacturer"
    year = parseInt($('#bike_year').val(),10)
    # could be bikebook.io - but then we'd have to pay for SSL...
    url = "https://bikebook.herokuapp.com//model_list/?manufacturer=#{mnfg}"
    url += "&year=#{year}" if year > 1
    $.ajax
      type: "GET"
      url: url
      success: (data, textStatus, jqXHR) ->
        setModelTypeahead(data)
      error: ->
        setModelTypeahead()

toggleRegistrationType = ->
  $('#registration-type-tabs a').toggleClass('current-type')
  if $('#registration-type-tabs a.current-type').hasClass('stolen')
    $('#stolen_fields_container').slideUp 'medium', ->
      $('#stolen_fields').appendTo('#stolen_fields_store')
    # $('.has-no-serial .stolen').fadeOut 'fast', ->
      $('#optional-phone').slideUp() if $('#optional-phone').length > 0
  else
    $('#stolen_fields').appendTo('#stolen_fields_container')
    # $('#stolen_fields_containter').html($('#stolen_fields').html())
    $('#stolen_fields_container').slideDown()
    $('#optional-phone').slideDown() if $('#optional-phone').length > 0


updateSerial = (e) ->
  if $(e.target).prop('checked') == true
    $('#bike_serial_number').val('absent').addClass('absent-serial')
  else
    $('#bike_serial_number').val('').removeClass('absent-serial')    

optionalFormUpdate = (e) ->
  # $(@).find('a').data('target')
  target = $(e.target)
  clickTarget = $(target.attr('data-target'))
  $(target.attr('data-toggle')).show().removeClass('currently-hidden')
  target.addClass('currently-hidden').hide()

  if target.hasClass('rm-block')
    clickTarget.find('select').val('')
    clickTarget.slideUp().removeClass('unhidden')
  else
    clickTarget.slideDown().addClass('unhidden').removeClass('currently-hidden')

otherManufacturerUpdate = ->
  current_value = $('#bike_manufacturer_id').val()
  expand_value = $('#bike_manufacturer_id').parents('.input-group').find('.other-value').text()
  hidden_other = $('#bike_manufacturer_id').parents('.input-group').find('.hidden-other')
  if parseInt(current_value, 10) == parseInt(expand_value, 10)
    # show the bugger!
    hidden_other.slideDown().addClass('unhidden')
  else 
    # if it's visible, clear it and slide up
    if hidden_other.hasClass('unhidden')
      hidden_other.find('input').val('')
      hidden_other.removeClass('unhidden').slideUp()

toggleUnknownYear = ->
  if $('#bike_unknown_year').prop('checked')
    $('#bike_year').val('').trigger('change')
    $('#bike_year').select2 "enable", false
  else
    $('#bike_year').val(new Date().getFullYear()).trigger('change')
    $('#bike_year').select2 "enable", true

updateYear = ->
  if $('#bike_year').val().length == 0
    $('#bike_year').select2 "enable", false
    $('#bike_unknown_year').prop('checked', true)
  else
    $('#bike_unknown_year').prop('checked', false)
  getModelList()

$(document).ready ->
  otherManufacturerUpdate()

  $('#bike_has_no_serial').change (e) ->
    updateSerial(e)
  
  $('#alert-block .close').click ->
    $('#alert-block').fadeOut('fast')

  $('a.optional-form-block').click (e) ->
    optionalFormUpdate(e)

  $('#bike_manufacturer_id').change ->
    otherManufacturerUpdate()
    getModelList()

  $('#bike_year').change ->
    updateYear()

  $('#bike_unknown_year').change ->
    toggleUnknownYear()

  $('.chosen-select select').select2()

  $('#registration-type-tabs a').click (e) ->
    e.preventDefault()
    if $('#bike_stolen').val() == "true"
      $('#bike_stolen').val(0)
    else
      $('#bike_stolen').val(1)
    toggleRegistrationType()

  $('#stolen_record_date_stolen_input').datepicker('format: mm-dd-yyy')
  $('#stolen_fields').appendTo('#stolen_fields_store')
  toggleRegistrationType() if $('#stolen_registration_first').length > 0