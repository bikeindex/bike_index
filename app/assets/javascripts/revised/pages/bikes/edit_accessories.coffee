class BikeIndex.BikesEditAccessories extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    @fancySelectForManufacturers()

  initializeEventListeners: ->
    pagespace = @
    $('#form_well_wrap').on 'click', '.remove-part label', (e) ->
      pagespace.removeComponent(e)
    $('#form_well_wrap').on 'change', '.component-ctype-input', (e) ->
      pagespace.toggleOtherDisplay(e, 'ctype')
    $('#form_well_wrap').on 'change', '.component-manufacturer-input', (e) ->
      pagespace.toggleOtherDisplay(e, 'manufacturer')
    $('.add_fields').click (e) ->
      pagespace.addComponent(e)

  toggleOtherDisplay: (e, field_type) ->
    $target = $(e.target)
    return true unless $target.hasClass 'form-control'
    other_id = $('#form_well_wrap').data("#{field_type}other")
    $other_field = $target.parents('.related-fields').find('.hidden-other')
    if "#{$target.val()}" == "#{other_id}"
      $other_field.slideDown 'fast', ->
        $other_field.addClass('unhidden').removeClass('currently-hidden')
    else
      $other_field.slideUp 'fast', ->
        $other_field.removeClass('unhidden').addClass('currently-hidden')
        $other_field.find('.form-control').val('')

  removeComponent: (e) ->
    # We don't need to do anything except slide the input up, because the label is on it.
    $target = $(e.target)
    $target.prev('input[type=hidden]').val('1')
    $target.closest('fieldset').slideUp()

  fancySelectForManufacturers: ->
    toggleOtherDisplay = @toggleOtherDisplay
    for m in $('.component-manufacturer-input.unfancy')
      new BikeIndex.ManufacturersSelect(m, false)

  addComponent: (e) ->
    e.preventDefault()
    $target = $('.add_fields')
    time = new Date().getTime()
    regexp = new RegExp($target.attr('data-id'), 'g')
    $target.before($target.data('fields').replace(regexp, time))
    window.BikeIndexInit.loadFancySelects()
    @fancySelectForManufacturers()
