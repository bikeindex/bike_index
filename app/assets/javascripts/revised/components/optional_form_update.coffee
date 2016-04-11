class BikeIndex.OptionalFormUpdate extends BikeIndex
  constructor: ->
    updateForm = @updateForm
    $('a.optional-form-block').click (e) ->
      updateForm(e)

  updateForm: (e) ->
    $target = $(e.target)
    unless $target.is('a') # Ensure we aren't clicking on an interior element
      $target = $target.parents('.optional-form-block')
    $click_target = $($target.attr('data-target'))
    $($target.attr('data-toggle')).show().removeClass('currently-hidden')
    $target.addClass('currently-hidden').hide()
    action = $target.attr('data-action')

    if action == 'rm-block'
      $click_target.slideUp().removeClass('unhidden').addClass('currently-hidden')
      selectize = $click_target.find('select').selectize()[0]
      selectize.selectize.setValue('') if selectize
    else if action == 'swap'
      $swap = $($target.attr('data-swap'))
      $swap.slideUp('fast', ->
        $click_target.fadeIn()
        $click_target.slideDown().addClass('unhidden').removeClass('currently-hidden')
        $swap.addClass('currently-hidden').removeClass('unhidden')
      )
      selectize = $click_target.find('select').selectize()[0]
      selectize.selectize.setValue('') if selectize
    else # It is showing a block. No action label required
      $click_target.slideDown()
      $click_target.slideDown().addClass('unhidden').removeClass('currently-hidden')
