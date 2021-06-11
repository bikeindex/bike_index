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

  googleAds = {
    "ad300x600": "4203947975",
    "ad468x60": "3828489557"
  }

  skyscrapers = ["max_tracker_300"]
  sm_rectangles = ["max_tracker_468"]

  constructor: ->
    @renderedAds = []
    @renderedGoogleAd = false

    for el_klass in ads_skyscraper
      $(".#{el_klass}").each (index, el) =>
        @renderedAds.push @renderAdElement(el, index, el_klass, skyscrapers)

    for el_klass in ads_sm_rectangle
      $(".#{el_klass}").each (index, el) =>
        @renderedAds.push @renderAdElement(el, index, el_klass, sm_rectangles)

    # If google analytics is loaded, create an event for each ad that is loaded, and track the clicks
    if window.ga
      for adname in @renderedAds
        window.ga("send", {hitType: "event", eventCategory: "advertisement", eventAction: "ad-load", eventLabel: "#{adname}"})
        $("#binxad-#{adname}").click (e) ->
          window.ga("send", {hitType: "event", eventCategory: "advertisement", eventAction: "ad-click", eventLabel: "#{adname}"})

  renderAdElement: (el, index, klass, adArray) ->
    el.classList.add("rendered-ad")
    if adArray[index]
      renderedAd = internalAds[adArray[index]]
      el.innerHTML = "<a href=\"#{renderedAd.href}\" id=\"binxad-#{adArray[index]}\">#{renderedAd.body}</a>"
      adArray[index]
    else
      @initializeGoogleAds() unless @renderedGoogleAd
      adId = googleAds[klass]
      el.innerHTML = "<ins class=\"adsbygoogle\" style=\"display:block;width:100%;height:100%;\" data-ad-client=\"ca-pub-8140931939249510\" data-ad-slot=\"#{adId}\" data-ad-format=\"auto\" data-full-width-responsive=\"true\"></ins>"
      (adsbygoogle = window.adsbygoogle || []).push({});
      "google_ad-#{adId}"

  initializeGoogleAds: ->
    # For some reason, doesn't work to dynamically add the script, so I added it to all the pages with ads
    # Ideally, we'd be able to dynamically add the script tag, but... just getting it working for now

    # googleadscript = document.createElement('script');
    # googleadscript.setAttribute("src", "https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js")
    # googleadscript.setAttribute("async", true)
    # document.head.appendChild(googleadscript)
    @renderedGoogleAd = true

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
