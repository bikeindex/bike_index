class BikeIndex.BikesEditAccessories extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    @fancySelectForManufacturers()

    manufacturer_other_val = $('#form_well_wrap').data('manufacturerother')
    ctype_other_val = $('#form_well_wrap').data('ctypeother')
    new BikeIndex.ToggleHiddenOther('.component-manufacturer-input', manufacturer_other_val)
    new BikeIndex.ToggleHiddenOther('.component-ctype-input', ctype_other_val)

  initializeEventListeners: ->
    $('#form_well_wrap').on 'click', '.remove-part label', (e) =>
      @removeComponent(e)
    $('.add_fields').click (e) =>
      @addComponent(e)

  removeComponent: (e) ->
    # We don't need to do anything except slide the input up, because the label is on it.
    $target = $(e.target)
    $target.prev('input[type=hidden]').val('1')
    $target.closest('fieldset').slideUp()

  fancySelectForManufacturers: ->
    toggleOtherDisplay = @toggleOtherDisplay
    for m in $('.component-manufacturer-input.unfancy')
      new window.ManufacturersSelect(m, false)

  addComponent: (e) ->
    e.preventDefault()
    $target = $('.add_fields')
    time = new Date().getTime()
    regexp = new RegExp($target.attr('data-id'), 'g')
    $target.before($target.data('fields').replace(regexp, time))
    @loadFancySelects()
    @fancySelectForManufacturers()
