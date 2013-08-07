class BikeIndex.Views.BikesChooseRegistration extends Backbone.View
  events:
    'click a.choose-type': 'updateBikeLink'
   
  initialize: ->
    @setElement($('#body'))
    @SetInitialRegistrationType()

  updateBikeLink: (e) ->
    @chooseBikeLink($(e.target))

  chooseBikeLink: (target) ->
    $('.choose-type').removeClass('current-choice')
    target.addClass('current-choice')
    new_location = target.attr('data-target')
    $('#add-bike').attr("href", new_location)

  SetInitialRegistrationType: ->
    target = $('.purchase-choice')
    if $('.free-tix-choice').length > 0
      target = $('.free-tix-choice').first()
    if $('.organization-choice').length > 0
      target = $('.organization-choice').first()
    @chooseBikeLink(target)