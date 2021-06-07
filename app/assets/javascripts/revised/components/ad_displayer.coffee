class @AdDisplayer
  ads_skyscraper = ["ad300x600"]
  ads_sm_rectangle = ["ad468x60"]

  # Note: links have id of binxad-#{ad name} - which enables click tracking with ga events
  max_tracker_300 = "<a id=\"binxad-max_tracker_300\" href=\"https://landing.mymaxtracker.com/\"><img src=\"/ads/maxtracker-300x600-2.jpg\" alt=\"MaxTracker\"></a>"
  max_tracker_468 = "<a id=\"binxad-max_tracker_468\" href=\"https://landing.mymaxtracker.com/\"><img src=\"/ads/maxtracker-468x60-2.jpg\" alt=\"MaxTracker\"></a>"

  internalAds = {
    "max_tracker_300": {
      "href": "https://landing.mymaxtracker.com",
      "body": "<img src=\"/ads/maxtracker-300x600-2.jpg\" alt=\"MaxTracker\">"
    },
    "max_tracker_468": {
      "href": "https://landing.mymaxtracker.com",
      "body": "<img src=\"/ads/maxtracker-468x60-2.jpg\" alt=\"MaxTracker\">"
    }
  }

  skyscrapers = ["max_tracker_300"]
  sm_rectangles = ["max_tracker_468"]

  constructor: ->
    renderedAds = []

    for el_klass in ads_skyscraper
      $(".#{el_klass}").each (index, el) =>
        renderedAds.push @renderAdElement(el, index, skyscrapers)
      # # if document.getElementsByClassName(el_klass)
      # for el, index in document.getElementsByClassName(el_klass)
      #   Array::push.apply renderedAds, @renderSkyscraperAd(el, index)
    for el_klass in ads_sm_rectangle
      # if document.getElementsByClassName(el_klass)
      # for el, index in document.getElementsByClassName(el_klass)
      $(".#{el_klass}").each (index, el) =>
        renderedAds.push @renderAdElement(el, index, sm_rectangles)
        # @renderAdElement(el, index, sm_rectangles)

    window.renderedAds = renderedAds

    # If google analytics is loaded, create an event for each ad that is loaded, and track the clicks
    if window.ga
      for adname in renderedAds
        window.ga("send", {hitType: "event", eventCategory: "advertisement", eventAction: "ad-load", eventLabel: "#{adname}"})
        $("#binxad-#{adname}").click (e) ->
          window.ga("send", {hitType: "event", eventCategory: "advertisement", eventAction: "ad-click", eventLabel: "#{adname}"})

  renderSkyscraperAd: (el, index) ->
    val = skyscrapers[index] || "Google ad"
    el.innerHTML = val
    el.classList.add("rendered-ad")
    "#{val}"
    # for el, index in document.querySelectorAll(".#{el_klass}")
    #   console.log(skyscrapers[index])

    # for el in document.getElementsByClassName(el_klass)
    #   el
    # $(".#{el_klass}").html([max_tracker_300].join("")).addClass("rendered-ad")

    # ["max_tracker_300"]

  renderSmRectangleAd: (el, index) ->
    val = sm_rectangles[index] || "Google ad"
    el.innerHTML = val
    el.classList.add("rendered-ad")
    "#{val}"
    # $(".#{el_klass}").html([max_tracker_468].join("")).addClass("rendered-ad")

    # ["max_tracker_468"]

  renderAdElement: (el, index, adArray) ->
    el.classList.add("rendered-ad")
    if adArray[index]
      renderedAd = internalAds[adArray[index]]
      el.innerHTML = "<a href=\"#{renderedAd.href}\" id=\"binxad-#{adArray[index]}\">#{renderedAd.body}</a>"
      adArray[index]
    else
      el.innerHTML = "Google ad"
      "Google ad"

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
