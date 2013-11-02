class BikeIndex.Views.BikesNew extends Backbone.View
  events:
    'change #bike_has_no_serial': 'updateSerial'
    'click a.optional-form-block': 'optionalFormUpdate'
    'change #bike_manufacturer_id': 'expandAdditionalBlock'
    'change #rear_standard': 'updateWheelDiam'
    'click #select-cycletype a': 'changeCycleType'
    
  
  initialize: ->
    @setElement($('#body'))
    if $('#bike_has_no_serial').prop('checked') == true
      $('#bike_serial_number').val('absent').addClass('absent-serial')
    
    @setWheelDiam('rear')
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

  # Right Now: Need to make the edit page work. New page should work
  # But I just tried to make the new page universal, and I can't guarantee anything.
  updateWheels: (target, clickTarget) ->
    standard = clickTarget.parents('.controls').find('.standard-diams')
    if target.hasClass('show-all')
      standard.fadeOut('fast', ->
        clickTarget.fadeIn()
      )
    else
      clickTarget.fadeOut('fast', ->
        clickTarget.val('')
        standard.val('')
        standard.fadeIn()
      )
  
  setWheelDiam: (position) ->
    wheelDiam = $("#bike_#{position}_wheel_size_id").val()
    if $("##{position}_standard option[value=#{wheelDiam}]").length
      $("##{position}_standard").val(wheelDiam)
      $("#bike_#{position}_wheel_size_id").hide()
    else
      $("##{position}_standard").hide()
      $("#show-#{position}-wheel-diams").addClass('currently-hidden').hide()
      $("#hide-#{position}-wheel-diams").removeClass('currently-hidden').show()
      

  updateWheelDiam: (event) ->
    target = $(event.target)
    cv = target.val()
    position = 'rear'
    $("#bike_#{position}_wheel_size_id").val(cv) if cv.length > 0


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
