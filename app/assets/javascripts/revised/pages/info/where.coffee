class BikeIndex.InfoWhere extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    google.maps.event.addDomListener(window, 'load', @initializeMap)

  initializeEventListeners: ->
    $('a.where-shop-location').click (e) =>
      @updateMapLocation(e)
  
  initializeMap: ->
    # Ideally we'll use the localstorage location information about the user 
    # Which is what we'll use for bike proximity searching for the user
    createMap(40.111689,-96.81839,4)

  updateMapLocation: (event) ->
    target = $(event.target)
    $('body').animate( 
      scrollTop: ($('#where-bike-index').offset().top - 20), 'fast' 
    )
    latLng = new google.maps.LatLng(target.attr('data-lat'), target.attr('data-long'))
    window.map.setZoom(13)
    window.map.panTo(latLng)