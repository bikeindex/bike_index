class BikeIndex.Views.BikesNew extends Backbone.View
  events:
    'change #bike_has_no_serial': 'updateSerial'
    'click a.optional-form-block': 'optionalFormUpdate'
    'change .with-additional-block select': 'expandAdditionalBlock'
    'change #standard-diams': 'updateWheelDiam'
    'click #select-cycletype a': 'changeCycleType'
    'change #bike_bike_image': 'updateFileName'
  
  initialize: ->
    @setElement($('#body'))
    if $('#bike_has_no_serial').prop('checked') == true
      $('#bike_serial_number').val('absent').addClass('absent-serial')
    
    if $('#bike_rear_wheel_size_id').val()
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

    if target.hasClass('rm-block')
      if clickTarget.find('select').attr('name') != 'bike[rear_wheel_size_id]'
        clickTarget.find('select').val('')
        clickTarget.slideUp().removeClass('unhidden')
      else
        wheelDiam = $('#bike_rear_wheel_size_id').val()
        if $("#standard-diams option[value=#{wheelDiam}]").length
          $('#standard-diams').val(wheelDiam)
        else
          $('#bike_rear_wheel_size_id').val('')
        clickTarget.slideUp().removeClass('unhidden').addClass('currently-hidden')
        
    else
      clickTarget.slideDown().addClass('unhidden').removeClass('currently-hidden')
      if clickTarget.find('select').attr('name') == 'bike[rear_wheel_size_id]'
        $('#standard-diams').val('')

  
  setWheelDiam: ->
    console.log('called')
    # If the rear wheel diam has a value, set the standard-diams, unless it isn't standard.
    wheelDiam = $('#bike_rear_wheel_size_id').val()
    if $("#standard-diams option[value=#{wheelDiam}]").length
      $('#standard-diams').val(wheelDiam)
    else
      $('#wheel-diams').show().addClass('unhidden')
      $('#show-wheel-diams').hide().addClass('currently-hidden')
      $('#hide-wheel-diams').show().removeClass('currently-hidden')
  
  updateWheelDiam: (event) ->
    current_value = $(event.target).val()
    $('#bike_rear_wheel_size_id').val(current_value)



  updateCycleType: ->
    # Slide down the other field if needed
    current_value = $("#bike_cycle_type_id").val()
    expand_value = $("#hidden-cycletype-other").find('.other-value').text()
    hidden_other = $("#hidden-cycletype-other").find('.hidden-other')
    if parseInt(current_value, 10) == parseInt(expand_value, 10)
      hidden_other.slideDown().addClass('unhidden')
    else 
      if hidden_other.hasClass('unhidden')
        hidden_other.find('input').val('')
        hidden_other.removeClass('unhidden').slideUp()
    # Rewrite the name
    current = $("#cycletype#{current_value}")
    $('#cycletype-text').removeClass('long-title')
    if current.hasClass('long-title')
      $('#cycletype-text').addClass('long-title')  
    $('#cycletype-text').text(current.text())


  changeCycleType: (event) ->
    target = $(event.target)
    $('#bike_cycle_type_id').val(target.attr("data-id"))
    @updateCycleType()

  expandAdditionalBlock: ->
    current_value = $(event.target).parents('.input-group').find('select').val()
    expand_value = $(event.target).parents('.input-group').find('.other-value').text()    
    hidden_other = $(event.target).parents('.input-group').find('.hidden-other')
    if parseInt(current_value, 10) == parseInt(expand_value, 10)
      # show the bugger!
      hidden_other.slideDown().addClass('unhidden')
    else 
      # if it's visible, clear it and slide up
      if hidden_other.hasClass('unhidden')
        hidden_other.find('input').val('')
        hidden_other.removeClass('unhidden').slideUp()



  updateFileName: ->
    name = $(event.target).val()
    # b = this.relatedElement.value = this.value
    regexp = new RegExp(/[\w-]+\..../)
    name = regexp.exec(name)[0]
    $('#filepath').text("#{name} ready")
