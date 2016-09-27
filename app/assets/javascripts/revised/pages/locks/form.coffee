class BikeIndex.LocksForm extends BikeIndex
  constructor: ->
    locks_other_id = $('.manufacturer-select').data('otherid')
    new BikeIndex.ToggleHiddenOther('#lock_manufacturer_id', locks_other_id)

    $('input[name="lock_types_select"]').on 'change', (e) ->
      lock_type = $('input[name="lock_types_select"]:checked').data("value")
      $('#lock_lock_type_id').val(lock_type)