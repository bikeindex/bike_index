class @AdDisplayer
  ads_syscraper = ['ad300x600']
  ads_sm_rectangle = ['ad468x60']

  # Note: links have id of binxad-#{ad name} - which enables click tracking with ga events
  max_tracker_300 = "<a id=\"binxad-max_tracker_300\" href=\"https://landing.mymaxtracker.com/\"><img src=\"/ads/maxtracker-300x600-2.jpg\" alt=\"MaxTracker\"></a>"
  max_tracker_468 = "<a id=\"binxad-max_tracker_468\" href=\"https://landing.mymaxtracker.com/\"><img src=\"/ads/maxtracker-468x60-2.jpg\" alt=\"MaxTracker\"></a>"

  constructor: ->
    renderedAds = []

    for el_id in ads_syscraper
      if document.getElementsByClassName(el_id)
        Array::push.apply renderedAds, @renderSkyscraper(el_id)

    for el_id in ads_sm_rectangle
      if document.getElementsByClassName(el_id)
        Array::push.apply renderedAds, @renderSmRectangle(el_id)

    # If google analytics is loaded, create an event for each ad that is loaded, and track the clicks
    if window.ga
      for adname in renderedAds
        window.ga("send", {hitType: "event", eventCategory: "advertisement", eventAction: "ad-load", eventLabel: "#{adname}"})
        $("#binxad-#{adname}").click (e) ->
          window.ga("send", {hitType: "event", eventCategory: "advertisement", eventAction: "ad-click", eventLabel: "#{adname}"})

  renderSkyscraper: (el_id) ->
    $(".#{el_id}").html([max_tracker_300].join("")).addClass("rendered-ad")

    ["max_tracker_300"]

  renderSmRectangle: (el_id) ->
    $(".#{el_id}").html([max_tracker_468].join("")).addClass("rendered-ad")

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
