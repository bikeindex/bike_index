class BikeIndex.OptionalFormUpdate extends BikeIndex
  constructor: ->
    updateForm = @updateForm
    # Add optional parameter for use when triggering manually (so we don't clear on initial setup)
    $('a.optional-form-block').click (e, erase = true) ->
      updateForm(e, erase)

  updateForm: (e, erase) ->
    e.preventDefault()
    $target = $(e.target)
    unless $target.is('a') # Ensure we aren't clicking on an interior element
      $target = $target.parents('.optional-form-block')
    $click_target = $($target.attr('data-target'))
    $($target.attr('data-toggle')).show().removeClass('currently-hidden')
    $target.addClass('currently-hidden').hide()
    action = $target.attr('data-action')

    if action == 'rm-block'
      $click_target.slideUp 'fast', ->
        $click_target.removeClass('unhidden').addClass('currently-hidden')

    else if action == 'swap'
      $swap = $($target.attr('data-swap'))
      $swap.slideUp 'fast', ->
        $click_target.fadeIn()
        $click_target.slideDown().addClass('unhidden').removeClass('currently-hidden')
        $swap.addClass('currently-hidden').removeClass('unhidden')

    else # It is showing a block. No action label required
      $click_target.slideDown 'fast', ->
        $click_target.addClass('unhidden').removeClass('currently-hidden')

    if erase
      selectize = $click_target.find('select').selectize()[0]
      selectize.selectize.setValue('') if selectize
