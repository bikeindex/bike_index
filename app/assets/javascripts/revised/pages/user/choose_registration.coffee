class BikeIndex.ChooseRegistration extends BikeIndex
  constructor: ->
    @SetInitialRegistrationType()
    $('a.choose-type').click (e) =>
      @updateBikeLink(e)

  updateBikeLink: (e) ->
    $target = $(e.target)
    unless $target.hasClass('choose-type')
      $target = $target.parents('.choose-type')
    @chooseBikeLink($target)

  chooseBikeLink: ($target) ->
    $('.choose-type').removeClass('current-choice')
    $target.addClass('current-choice')
    new_location = $target.attr('data-target')
    $('#add-bike').attr('href', new_location)

  SetInitialRegistrationType: ->
    $target = $('.purchase-choice')
    if $('.free-tix-choice').length > 0
      $target = $('.free-tix-choice').first()
    if $('.organization-choice').length > 0
      $target = $('.organization-choice').first()
    @chooseBikeLink($target)

