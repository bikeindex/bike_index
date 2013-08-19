class BikeIndex.Views.BikesSearch extends Backbone.View
  events:
    'click a.choose-type': 'updateBikeLink'
   
  initialize: ->
    @setElement($('#body'))
    @setInitialValues()

  updateBikeLink: (e) ->
    t = $(e.target)
    unless t.hasClass('choose-type')
      t = $(t.parents('.choose-type'))
    @chooseBikeLink(t)

  chooseBikeLink: (target) ->
    $('.choose-type').removeClass('current-choice')
    target.addClass('current-choice')
    new_location = target.attr('data-target')
    $('#add-bike').attr("href", new_location)

  setInitialValues: ->
    $('#total-top-header').addClass('search-expanded')
    
    for input in $('#header-search .stolenness input')
      $(input).prop('checked', false) unless $(input).attr("value") == "on"
        
        