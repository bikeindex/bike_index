class @AdDisplayer
  ads_right = ['right300x600']
  ads_top = ['top468x60']

  max_tracker_300 = "<a href=\"https://landing.mymaxtracker.com/\"><img src=\"/ads/maxtracker-300x600.jpg\" alt=\"MaxTracker\"></a>"
  max_tracker_468 = "<a href=\"https://landing.mymaxtracker.com/\"><img src=\"/ads/maxtracker-468x60.jpg\" alt=\"MaxTracker\"></a>"

  constructor: ->
    for el_id in ads_right
      @renderAdRight(el_id) if document.getElementById(el_id)

    for el_id in ads_top
      @renderAdTop(el_id) if document.getElementById(el_id)

  renderAdRight: (el_id) ->
    $(".content-nav-group:last").addClass("additional-ad-space")
    $("##{el_id}").html([max_tracker_300].join("")).addClass("rendered-ad")

  renderAdTop: (el_id) ->
    $("##{el_id}").html([max_tracker_468].join("")).addClass("rendered-ad")

  # geolocatedAd: ->
  #   location = localStorage.getItem('location')
  #   if location?
  #     # Wrap the string in blank space so it's possible to check for non word chars
  #     location = " #{location.toLowerCase()} "
  #     for match in lemonade_location_matches
  #       # Check if the matching strings are separate words in the location string
  #       expression = ///[^\w]#{match}[^\w]///
  #       return lemonade_ad if location.match(///[^\w]#{match}[^\w]///)
  #   else
  #     # Display it anyway, our location tracking is sort of BS
  #     return lemonade_ad
  #   # return an empty string if there aren't any matches
  #   ''
