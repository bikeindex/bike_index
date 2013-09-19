class BikeIndex.Views.BikesSearch extends Backbone.View

  initialize: ->
    @setElement($('#body'))
    @setInitialValues()
    $('.content .receptacle').addClass('bike-search-page')
  setInitialValues: ->
    $('#total-top-header').addClass('search-expanded')
    @selectCurrentAttributes()
    BikeIndex.initializeHeaderSearch()
    $('#header-search #stolen_included').prop('checked', true) if parseInt($('#stolen_searched').text()) == 1
    $('#header-search #non_stolen_included').prop('checked', true) if parseInt($('#non_stolen_searched').text(), 10) == 1
    $('#header-search #query').val($('#query_searched').text())


  selectCurrentAttributes: ->
    a_values = $("#attribute_values_searched").text()
    if a_values.length > 3
      $('#find_bike_attributes_ids').val(JSON.parse(a_values))