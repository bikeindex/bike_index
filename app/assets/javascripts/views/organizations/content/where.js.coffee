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
    # event.preventDefault()
    target = $(event.target)
    $('body').animate( 
      scrollTop: ($('#where-bike-index').offset().top - 20), 'fast' 
    )
    latLng = new google.maps.LatLng(target.attr('data-lat'), target.attr('data-long'))
    window.map.setZoom(8)
    window.map.panTo(latLng)
    
    
  # initialize
  #   if(navigator.geolocation) {
  #     success = function(position) {
  #       createMap(position.coords.latitude, position.coords.longitude,12);
  #     };
  #     error = function() {createMap(41.869561,-87.495117,6); }
  #     navigator.geolocation.getCurrentPosition(success, error);
  #   }
  #   else {