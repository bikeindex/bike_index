# All the classes inherit from this
class window.BikeIndex
  loadFancySelects: ->
    $('.unfancy.fancy-select select').selectize
      create: false
      plugins: ['restore_on_backspace']
    $('.unfancy.fancy-select-placeholder select').selectize # When empty options are allowed
      create: false
      plugins: ['restore_on_backspace', 'selectable_placeholder']
    # Remove them so we don't initialize twice
    $('.unfancy.fancy-select, .unfancy.fancy-select-placeholder').removeClass('unfancy')