class BikeIndex.LocksForm extends BikeIndex
  constructor: ->
    locks_other_id = $('.manufacturer-select').data('otherid')
    new BikeIndex.ToggleHiddenOther('#lock_manufacturer_id', locks_other_id)