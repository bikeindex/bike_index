class @AdDisplayer
  ads_right = ['right300x600']
  ads_top = ['top468x60']

  # Note: links have id of binxad-#{ad name} - which enables click tracking with ga events
  max_tracker_300 = "<a id=\"binxad-max_tracker_300\" href=\"https://landing.mymaxtracker.com/\"><img src=\"/ads/maxtracker-300x600-2.jpg\" alt=\"MaxTracker\"></a>"
  max_tracker_468 = "<a id=\"binxad-max_tracker_468\" href=\"https://landing.mymaxtracker.com/\"><img src=\"/ads/maxtracker-468x60-2.jpg\" alt=\"MaxTracker\"></a>"

  constructor: ->
    renderedAds = []

    for el_id in ads_right
      if document.getElementById(el_id)
        Array::push.apply renderedAds, @renderAdRight(el_id)

    for el_id in ads_top
      if document.getElementById(el_id)
        Array::push.apply renderedAds, @renderAdTop(el_id)

    # If google analytics is loaded, create an event for each ad that is loaded, and track the clicks
    if window.ga
      for adname in renderedAds
        window.ga("send", {hitType: "event", eventCategory: "advertisement", eventAction: "ad-load", eventLabel: "#{adname}"})
        $("#binxad-#{adname}").click (e) ->
          window.ga("send", {hitType: "event", eventCategory: "advertisement", eventAction: "ad-click", eventLabel: "#{adname}"})

  renderAdRight: (el_id) ->
    $(".content-nav-group:last").addClass("additional-ad-space")
    $("##{el_id}").html([max_tracker_300].join("")).addClass("rendered-ad")

    ["max_tracker_300"]

  renderAdTop: (el_id) ->
    $("##{el_id}").html([max_tracker_468].join("")).addClass("rendered-ad")

    ["max_tracker_468"]

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
