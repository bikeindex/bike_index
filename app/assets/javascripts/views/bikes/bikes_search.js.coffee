class BikeIndex.Views.BikesSearch extends Backbone.View

  initialize: ->
    @setElement($('#body'))
    @setInitialValues()

  setInitialValues: ->
    $('#total-top-header').addClass('search-expanded')
    @selectCurrentAttributes()
    BikeIndex.initializeHeaderSearch()
    $('#header-search #stolen_included').prop('checked', true) if $('#stolen_searched')
    $('#header-search #non_stolen_included').prop('checked', true) if $('#non_stolen_searched')
    $('#header-search #query').val($('#query_searched').text())

  selectCurrentAttributes: ->
    a_values = $("#attribute_values_searched").text()
    if a_values.length > 3
      $('#find_bike_attributes_ids').val(JSON.parse(a_values))