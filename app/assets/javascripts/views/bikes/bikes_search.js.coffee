class BikeIndex.Views.BikesSearch extends Backbone.View

  initialize: ->
    @setElement($('#body'))
    @setInitialValues()

  setInitialValues: ->
    $('#total-top-header').addClass('search-expanded')
    for input in $('#header-search .stolenness input')
      $(input).prop('checked', false) unless $(input).attr("value") == "on"
    m_values = $("#manufacturer_select_values").text()
    a_values = $("#attribute_select_values").text()
    if m_values.length > 3
      $('#find_manufacturers_ids').val(JSON.parse(m_values))
    if a_values.length > 3
      $('#find_bike_attributes_ids').val(JSON.parse(a_values))
    BikeIndex.initializeHeaderSearch()

        