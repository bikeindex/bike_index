class BikeIndex.Views.BikesSearch extends Backbone.View

  initialize: ->
    @setElement($('#body'))
    @setInitialValues()

  setInitialValues: ->
    $('#total-top-header').addClass('search-expanded')
    for input in $('#header-search .stolenness input')
      $(input).prop('checked', false) unless $(input).attr("value") == "on"

    BikeIndex.initializeHeaderSearch()
        
        