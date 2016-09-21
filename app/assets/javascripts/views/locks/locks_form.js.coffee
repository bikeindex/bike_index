class BikeIndex.Views.LocksForm extends Backbone.View
  events: 
    'change #lock_has_key': 'updateLockFields'
    'change #lock_has_combination': 'updateLockFields'
    'change input[name="lock_types_select"]': 'updateLockType'
    'change .manufacturer-select select': 'showOtherIfRequired'
    'click .lock-picture': 'openLockPicture'
    
  
  initialize: ->
    @setElement($('#body'))
    @selectCorrectLock()

  openLockPicture: (e) ->
    e.preventDefault()
    target = $(e.target)
    unless target.hasClass('.lock-picture')
      target = target.parents('.lock-picture')
    local = target.attr("data-target")
    window.open(local, '_blank')

  selectCorrectLock: ->
    # Select the lock type from the initial value
    lock_type_id = $('#lock_lock_type_id').val()
    $("#locky_#{parseInt(lock_type_id)}").prop('checked', true)
    @updateLockFields()


  showOtherIfRequired: (event) ->
    current_value = $(event.target).val()
    other_value = $(event.target).parents('.input-field').find('.other-value').text()
    hidden_other = $(event.target).parents('.input-field').find('.hidden-other')
    if parseInt(current_value) == parseInt(other_value)
      hidden_other.slideDown().addClass('unhidden')
    else 
      if hidden_other.hasClass('unhidden')
        hidden_other.find('input').val('')
        hidden_other.removeClass('unhidden').slideUp()
    
  updateLockType: ->
    lock_type = $('input[name="lock_types_select"]:checked').data("value")
    $('#lock_lock_type_id').val(lock_type)
    

  updateLockFields: ->
    if $('input[name="lock[has_key]"]:checked').length > 0
      $('#serial-group').addClass('visibled').slideDown('fast')
    else
      if $('#serial-group').hasClass('visibled')
        $('#serial-group').slideUp('fast').find('input').val('')
    if $('input[name="lock[has_combination]"]:checked').length > 0
      $('#combination').addClass('visibled').slideDown()
    else
      if $('#combination').hasClass('visibled')
        $('#combination').slideUp('fast').find('input').val('')
