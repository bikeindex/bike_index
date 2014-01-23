updateSerial = (e) ->
    if $(e.target).prop('checked') == true
      $('#bike_serial_number').val('absent').addClass('absent-serial')
    else
      $('#bike_serial_number').val('').removeClass('absent-serial')    

updateWheelDiam = (e) ->
  current_value = $(e.target).val()
  $('#bike_rear_wheel_size_id').val(current_value)



optionalFormUpdate = (e) ->
  # $(@).find('a').data('target')
  target = $(e.target)
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



$(document).ready ->
  if $('#bi-slide-prev').length > 0
    window.mySwipe = new Swipe(document.getElementById('slider'), 
      auto: 4000
    )
    $('#bi-slide-prev').click (e) ->
      mySwipe.prev()
    $('#bi-slide-next').click (e) ->
      mySwipe.next()

  # $('#bike_has_no_serial').change (e) ->
  #   updateSerial(e)

  # $('#alert-block .close').click ->
  #   $('#alert-block').fadeOut('fast')

  # $('a.optional-form-block').click (e) ->
  #   optionalFormUpdate(e)

  # $('#standard-diams').change (e) ->
  #   updateWheelDiam(e)

  # $('.chosen-select select').select2()

