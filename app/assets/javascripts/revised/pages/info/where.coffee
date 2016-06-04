class BikeIndex.InfoWhere extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    google.maps.event.addDomListener(window, 'load', @initializeMap)

  initializeEventListeners: ->
    pagespace = @
    $('a.where-shop-location').click (e) ->
      pagespace.updateMapLocation(e)
  
  initializeMap: ->
    $.ajax
      type: "GET"
      url: 'https://freegeoip.net/json/'
      dataType: "jsonp",
      success: (location) ->
        createMap(location.latitude,location.longitude,7)
      error: (location) ->
        createMap(40.111689,-96.81839,4)

  updateMapLocation: (event) ->
    target = $(event.target)
    $('body').animate( 
      scrollTop: ($('#where-bike-index').offset().top - 20), 'fast' 
    )
    latLng = new google.maps.LatLng(target.attr('data-lat'), target.attr('data-long'))
    window.map.setZoom(13)
    window.map.panTo(latLng)