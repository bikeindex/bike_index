class BikeIndex.ToggleHiddenOther extends BikeIndex
  constructor: (target_input_selector, other_val) ->
    # Perhaps misguided sentiment that binding to a selector with an ID is better than just
    # via a class...
    form_well_id = $('.primary-edit-bike-form').prop('id')
    toggleOtherDisplay = @toggleOtherDisplay

    $("##{form_well_id}").on 'change', target_input_selector, (e) ->
      toggleOtherDisplay(e, other_val)

  toggleOtherDisplay: (e, other_val) ->
    $target = $(e.target)
    return true unless $target.hasClass 'form-control'
    $other_field = $target.parents('.related-fields').find('.hidden-other')
    if "#{$target.val()}" == "#{other_val}"
      $other_field.slideDown 'fast', ->
        $other_field.addClass('unhidden').removeClass('currently-hidden')
    else
      $other_field.slideUp 'fast', ->
        $other_field.removeClass('unhidden').addClass('currently-hidden')
        $other_field.find('.form-control').val('')