initializeFrameMaker = (target) ->
  $(target).select2
    # allowClear: true
    placeholder: 'Choose a manufacturer'
    minimumInputLength: 0
    ajax:
      url: "#{window.root_url}/api/autocomplete"
      dataType: 'json'
      # width: 'style'
      delay: 250
      data: (params) ->
        {
          q: params.term
          page: params.page
          per_page: 10
        }
      processResults: (data, page) ->
        {
          results: data.matches.map((item) ->
            {
              id: item.id
              text: item.text
            }
          )
          pagination: more: data.matches.length == 10
        }
  $(target).on "change", (e) ->
    slug = $(target).val()
    otherManufacturerDisplay(slug)
    getModelList(slug)

setModelTypeahead = (data=[]) ->
  autocomplete = $('#bike_frame_model').typeahead()
  autocomplete.data('typeahead').source = data 
  # $('#bike_frame_model').typeahead({source: data})

getModelList = (mnfg_name='absent') ->
  if mnfg_name == 'absent'
    setModelTypeahead()
  else
    year = parseInt($('#bike_year').val(),10)
    # could be bikebook.io - but then we'd have to pay for SSL...
    url = "https://bikebook.herokuapp.com/model_list/?manufacturer=#{mnfg_name}"
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
    $('#stolen_record_phone').attr('required', false)
    $('#stolen_fields_container').slideUp 'medium', ->
      $('#stolen_fields').appendTo('#stolen_fields_store')
    # $('.has-no-serial .stolen').fadeOut 'fast', ->
      $('#optional-phone').slideUp() if $('#optional-phone').length > 0
  else
    $('#stolen_record_phone').attr('required', true)
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

otherManufacturerDisplay = (current_value) ->
  expand_value = 'other'
  hidden_other = $('#bike_manufacturer_id').parents('.input-group').find('.hidden-other')
  if current_value == expand_value
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

  slug = $('#bike_manufacturer_id').val()
  if slug.length > 0
    getModelList(slug)

  else
    getModelList()

$(document).ready ->
  window.root_url = $('#root_url').attr('data-url')
  initializeFrameMaker("#bike_manufacturer_id")
  otherManufacturerDisplay($("#bike_manufacturer_id").val())
  $('#stolen_record_phone').attr('required', false)

  $('#bike_has_no_serial').change (e) ->
    updateSerial(e)
  
  $('#alert-block .close').click ->
    $('#alert-block').fadeOut('fast')

  $('a.optional-form-block').click (e) ->
    optionalFormUpdate(e)

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