class BikeIndex.Views.ContentWhere extends Backbone.View

  events:
    'click a.where-shop-location': 'updateMapLocation'


  initialize: ->
    @setElement($('#body'))
    google.maps.event.addDomListener(window, 'load', @initializeMap);

  
  initializeMap: ->
    # createMap(41.869561,-87.495117,4);
    createMap(40.111689,-96.81839,4);

  updateMapLocation: (event) ->
    target = $(event.target)
    $('body').animate( 
      scrollTop: ($('#where-bike-index').offset().top - 20), 'fast' 
    )
    latLng = new google.maps.LatLng(target.attr('data-lat'), target.attr('data-long'))
    window.map.setZoom(13)
    window.map.panTo(latLng)