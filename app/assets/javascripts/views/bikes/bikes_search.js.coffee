class BikeIndex.Views.BikesSearch extends Backbone.View

  initialize: ->
    @setElement($('#body'))
    @setInitialValues()

  setInitialValues: ->
    $('#total-top-header').addClass('search-expanded')
    @selectCurrentAttributes()
    BikeIndex.initializeHeaderSearch()
    for input in $('#header-search .stolenness input')
      $(input).prop('checked', false) unless $(input).attr("value") == "on"

  selectCurrentAttributes: ->
    a_values = $("#attribute_select_values").text()
    if a_values.length > 3
      $('#find_bike_attributes_ids').val(JSON.parse(a_values))