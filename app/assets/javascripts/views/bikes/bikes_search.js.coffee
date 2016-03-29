class BikeIndex.Views.BikesSearch extends Backbone.View
  events:
    'click #proximity_tab': 'proximitySearch'
    'click #stolen_tab': 'stolenSearch'
    'click #non_stolen_tab': 'nonStolenSearch'


  initialize: ->
    $('.stolen-search-link').hide()
    $('.stolen-search-fields').show()
    @setElement($('#body'))
    $('.content .receptacle').addClass('bike-search-page')

  stolenSearch: (e) ->
    e.preventDefault()
    $('#stolen').val('true')
    $('#non_stolen').val('')
    $('#non_proximity').val('true')
    $('#head-search-bikes').submit()

  nonStolenSearch: (e) ->
    e.preventDefault()
    $('#stolen').val('')
    $('#non_stolen').val('true')
    $('#head-search-bikes').submit()

  proximitySearch: (e) ->
    e.preventDefault()
    $('#stolen').val('true')
    $('#non_stolen').val('')
    $('#non_proximity').val('')
    $('#head-search-bikes').submit()
