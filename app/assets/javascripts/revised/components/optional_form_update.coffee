class BikeIndex.OptionalFormUpdate extends BikeIndex
  constructor: (e) ->
    $target = $(e.target)
    console.log($target)
    $click_target = $($target.attr('data-target'))
    console.log $click_target
    $($target.attr('data-toggle')).show().removeClass('currently-hidden')
    $target.addClass('currently-hidden').hide()
    if $target.hasClass('wh_sw')
      @updateWheels($target, $click_target)
    else
      if $target.hasClass('rm-block')
        $click_target.slideUp().removeClass('unhidden').addClass('currently-hidden')
        selectize = $click_target.find('select').selectize()[0]
        selectize.selectize.setValue('') if selectize
      else
        console.log $click_target.slideDown()
        $click_target.slideDown().addClass('unhidden').removeClass('currently-hidden')

  updateWheels: ($target, $click_target) ->
    $standard = $click_target.parents('.controls').find('.standard-diams')
    $all = $click_target.parents('.controls').find('.all-dims')
    if $target.hasClass('show-all')
      $standard.fadeOut('fast', ->
        $click_target.fadeIn()
      )
    else
      $all.fadeOut('fast', ->
        $standard.find('select').selectize()[0].selectize.setValue(all.find('select').val())
        $standard.fadeIn()
      )