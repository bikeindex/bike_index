class BikeIndex.Views.BikesNew extends Backbone.View
  events:
    'change #bike_has_no_serial': 'updateSerial'
    'click a.optional-form-block': 'optionalFormUpdate'
    'change #bike_manufacturer_id': 'updateManufacturer'
    'change #bike_year': 'getModelList'
    'click #select-cycletype a': 'changeCycleType'
    
  
  initialize: ->
    @setElement($('#body'))
    if $('#bike_has_no_serial').prop('checked') == true
      $('#bike_serial_number').val('absent').addClass('absent-serial')
    
    @updateCycleType()

  

  updateSerial: (event) ->
    if $(event.target).prop('checked') == true
      $('#bike_serial_number').val('absent').addClass('absent-serial')
    else
      $('#bike_serial_number').val('').removeClass('absent-serial')


  optionalFormUpdate: (event) ->
    target = $(event.target)
    clickTarget = $(target.attr('data-target'))
    $(target.attr('data-toggle')).show().removeClass('currently-hidden')
    target.addClass('currently-hidden').hide()
    if target.hasClass('wh_sw')
      @updateWheels(target, clickTarget)
    else
      if target.hasClass('rm-block')
        clickTarget.slideUp().removeClass('unhidden').addClass('currently-hidden')
      else
        clickTarget.slideDown().addClass('unhidden').removeClass('currently-hidden')
  updateCycleType: ->
    current_value = $("#cycletype#{$("#bike_cycle_type_id").val()}")
    $('#cycletype-text').removeClass('long-title')
    if current_value.hasClass('long-title')
      $('#cycletype-text').addClass('long-title')  
    $('#cycletype-text').text(current_value.text())


  changeCycleType: (event) ->
    target = $(event.target)
    $('#bike_cycle_type_id').val(target.attr("data-id"))
    @updateCycleType()

  setModelTypeahead: (data=[]) ->
    autocomplete = $('#bike_frame_model').typeahead()
    autocomplete.data('typeahead').source = data 
    # $('#bike_frame_model').typeahead({source: data})

  getModelList: ->
    mnfg = $('#bike_manufacturer_id option:selected').text()
    unless mnfg == "Choose manufacturer"
      year = parseInt($('#bike_year').val(),10)
      url = "http://bikebook.io/model_list/?manufacturer=#{mnfg}"
      url += "&year=#{year}" if year > 1
      that = @
      $.ajax
        type: "GET"
        url: url
        success: (data, textStatus, jqXHR) ->
          that.setModelTypeahead(data)
        error: ->
          that.setModelTypeahead()



  updateManufacturer: ->
    @otherManufacturerDisplay()
    @getModelList()
    


  otherManufacturerDisplay: ->
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
