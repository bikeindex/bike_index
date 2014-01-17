class BikeIndex.Views.BikesSearch extends Backbone.View

  initialize: ->
    @setElement($('#body'))
    @setInitialValues()
    $('.content .receptacle').addClass('bike-search-page')

  setInitialValues: ->
    $('#total-top-header').addClass('search-expanded')
    @selectCurrentAttributes()
    BikeIndex.initializeHeaderSearch()
    @selectStolenness()
    $('#header-search #query').val($('#query_searched').text())


  selectCurrentAttributes: ->
    a_values = $("#attribute_values_searched").text()
    if a_values.length > 3
      $('#find_bike_attributes_ids').val(JSON.parse(a_values))

  selectStolenness: ->
    # We need to leave them on if they are both selected or neither are selected.
    stolenness = ["stolen", "non_stolen"]
    stolenness.shift() if $('#stolenness_query').attr('data-stolen')
    stolenness.pop() if $('#stolenness_query').attr('data-nonstolen')
    # So we do something if only one is selected
    if stolenness.length == 1
      $("##{stolenness[0]}").prop('checked',false)
    