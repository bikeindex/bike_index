class BikeIndex.ToggleHiddenOther extends BikeIndex
  constructor: (target_input_selector, other_val) ->
    # Perhaps misguided sentiment that binding to a selector with an ID is better than just
    # via a class...
    form_well_id = $('.primary-edit-bike-form').prop('id')
    form_well_id = $('body > form').prop('id') unless form_well_id # e.g. new bike page
    form_well_id = $("#{target_input_selector}").parents('form').prop('id') unless form_well_id # e.g. new bike page

    toggleOtherDisplay = @toggleOtherDisplay

    $("##{form_well_id}").on 'change', target_input_selector, (e) ->
      toggleOtherDisplay(e, other_val)

  toggleOtherDisplay: (e, other_val) ->
    $target = $(e.target)
    return true unless $target.hasClass 'form-control'
    $related = $target.parents('.related-fields')
    $other_field = $related.find('.hidden-other')
    $shown_field = $related.find('.shown-other')
    if "#{$target.val()}" == "#{other_val}"
      $other_field.slideDown 'fast', ->
        $other_field.addClass('unhidden').removeClass('currently-hidden')
      $shown_field.slideUp 'fast', ->
        $shown_field.removeClass('unhidden').addClass('currently-hidden')
        $shown_field.find('.form-control').val('')
    else
      $other_field.slideUp 'fast', ->
        $other_field.removeClass('unhidden').addClass('currently-hidden')
        $other_field.find('.form-control').val('')
      $shown_field.slideDown 'fast', ->
        $shown_field.addClass('unhidden').removeClass('currently-hidden')
