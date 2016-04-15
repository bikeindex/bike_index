class BikeIndex.BikesEditAccessories extends BikeIndex
  constructor: ->
    @initializeEventListeners()

  initializeEventListeners: ->
    pagespace = @
    $('.remove_fields').click (e) ->
      pagespace.removeComponent(e)
    $('.add_fields').click (e) ->
      pagespace.addComponent(e)

  removeComponent: (e) ->
    # We don't need to do anything except slide the input up, because the label is on it.
    $target = $(e.target)
    $target.prev('input[type=hidden]').val('1')
    $target.closest('fieldset').slideUp()

  addComponent: (e) ->
    e.preventDefault()
    $target = $('.add_fields')
    time = new Date().getTime()
    regexp = new RegExp($target.attr('data-id'), 'g')
    $target.before($target.data('fields').replace(regexp, time))
    $('.add-component-fields .special-select-single.select_unattached select').selectize
      plugins: ['restore_on_backspace']
      create: false
    new BikeIndex.ManufacturersSelect(m) for m in $('.component-mnfg-select.select_unattached input')
