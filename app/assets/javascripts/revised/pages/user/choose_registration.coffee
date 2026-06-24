class BikeIndex.ChooseRegistration extends BikeIndex
  constructor: ->
    @SetInitialRegistrationType()
    $('a.choose-type').click (e) =>
      e.preventDefault()
      @updateBikeLink(e)

  updateBikeLink: (e) ->
    $target = $(e.target)
    unless $target.hasClass('choose-type')
      $target = $target.parents('.choose-type')
    @chooseBikeLink($target)

  chooseBikeLink: ($target) ->
    $('.choose-type').removeClass('current-choice').removeAttr('aria-current')
    $target.addClass('current-choice').attr('aria-current', 'true')
    new_location = $target.attr('href')
    $('#add-bike').attr('href', new_location)

  SetInitialRegistrationType: ->
    $target = $('.purchase-choice')
    if $('.free-tix-choice').length > 0
      $target = $('.free-tix-choice').first()
    if $('.organization-choice').length > 0
      $target = $('.organization-choice').first()
    @chooseBikeLink($target)

