class BikeIndex.Views.BikesNew extends Backbone.View
  events:
    'change #bike_has_no_serial': 'updateSerial'
    'click a.optional-form-block': 'optionalFormUpdate'
    'change #bike_manufacturer_id': 'expandAdditionalBlock'
    'change #standard-diams': 'updateWheelDiam'
    'click #select-cycletype a': 'changeCycleType'
    
  
  initialize: ->
    @setElement($('#body'))
    if $('#bike_has_no_serial').prop('checked') == true
      $('#bike_serial_number').val('absent').addClass('absent-serial')
    @setWheelDiam()

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


  updateWheels: (target, clickTarget) ->
    clickTarget.parents('.controls').find('select').val('')
    standard = clickTarget.parents('.controls').find('.standard-diams')
    if target.hasClass('show-all')
      standard.fadeOut('fast', ->
        clickTarget.fadeIn()
      )
    else
      clickTarget.fadeOut('fast', ->
        standard.fadeIn()
      )
  
  setWheelDiam: ->
    wheelDiam = $('#bike_rear_wheel_size_id').val()
    if $("#r_standard option[value=#{wheelDiam}]").length
      $('#r_standard').val(wheelDiam)
      $('#bike_rear_wheel_size_id').hide()
    else
      $('#r_standard').hide()
      
    # If the rear wheel diam has a value, set the standard-diams, unless it isn't standard.
    # wheelDiam = $('#bike_rear_wheel_size_id').val()
    # if $("#standard-diams option[value=#{wheelDiam}]").length
    #   $('#standard-diams').val(wheelDiam)
    # else
    #   $('#wheel-diams').show().addClass('unhidden')
    #   $('#show-wheel-diams').hide().addClass('currently-hidden')
    #   $('#hide-wheel-diams').show().removeClass('currently-hidden')
  
  updateWheelDiam: (event) ->
    cv = $(event.target).val()
    $('#bike_rear_wheel_size_id').val(cv) if cv.length > 0


  updateCycleType: ->
    # Slide down the other field if needed
    # But there is no other field for now...
    # current_value = $("#bike_cycle_type_id").val()
    # expand_value = $("#hidden-cycletype-other").find('.other-value').text()
    # hidden_other = $("#hidden-cycletype-other").find('.hidden-other')
    # if parseInt(current_value, 10) == parseInt(expand_value, 10)
    #   hidden_other.slideDown().addClass('unhidden')
    # else 
    #   if hidden_other.hasClass('unhidden')
    #     hidden_other.find('input').val('')
    #     hidden_other.removeClass('unhidden').slideUp()
    # Rewrite the name
    current_value = $("#cycletype#{$("#bike_cycle_type_id").val()}")
    $('#cycletype-text').removeClass('long-title')
    if current_value.hasClass('long-title')
      $('#cycletype-text').addClass('long-title')  
    $('#cycletype-text').text(current_value.text())


  changeCycleType: (event) ->
    target = $(event.target)
    $('#bike_cycle_type_id').val(target.attr("data-id"))
    @updateCycleType()

  expandAdditionalBlock: ->
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
