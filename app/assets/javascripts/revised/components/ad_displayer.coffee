class @AdDisplayer
  ad_types = [
    {kind: "skyscraper", klass: "ad300x600"},
    {kind: "sm_rectangle", klass: "ad468x60"}
    # {kind: "full_width", klass: "adFullWidth"} # currently only via google
  ]

  # Note: links have id of binxad-#{ad name} - which enables click tracking with ga events
  max_tracker_url = "https://www.indiegogo.com/projects/maxtracker-anti-theft-gps-bicycle-security-system--2#/"
  ottalaus_url = "https://ottalausinc.ca/"

  internalAds = [
    {
      kind: "skyscraper",
      href: max_tracker_url,
      body: "<img src=\"/ads/maxtracker-300x600-2.jpg\" alt=\"MaxTracker\">"
    }, {
      kind: "sm_rectangle",
      href: max_tracker_url,
      body: "<img src=\"/ads/maxtracker-468x60-2.jpg\" alt=\"MaxTracker\">"
    }, {
      kind: "skyscraper",
      href: ottalaus_url,
      body: "<img src=\"/ads/ottalaus-468.png\" alt=\"Ottalaus\">"
    }, {
      kind: "sm_rectangle",
      href: ottalaus_url,
      body: "<img src=\"/ads/ottalaus-300.png\" alt=\"Ottalaus\">"
    }
  ]

  # Absolutely biased shuffle, but whatever! Better than nothing. And it works with a small number of elements
  # Doing it twice seems to fix an error where it didn't actually shuffle
  shuffle: (a) ->
    b = a.sort -> 0.5 - Math.random()
    b.sort -> 0.5 - Math.random()

  constructor: ->
    @renderedAds = []
    # Google ads are rendered on blocks with class .ad-google
    # our ads are rendered on blocks with class .ad-binx
    # TODO: don't use jquery here for the element iterating

    for ad_type in ad_types
      available = internalAds.filter (x) -> x.kind == ad_type.kind
      # # available = ad for ad in internalAds when ad.kind == ad_type.kind
      console.log available.map (ad) -> ad.body
    return

    # Remove undefined ads (ie they weren't rendered)
    @renderedAds = @renderedAds.filter (x) ->
      x != undefined

    # TODO: not tracking google ad loading. Should be tracking it too.
    # If google analytics is loaded, create an event for each ad that is loaded, and track the clicks
    if window.ga
      for adname in @renderedAds
        window.ga("send", {hitType: "event", eventCategory: "advertisement", eventAction: "ad-load", eventLabel: "#{adname}"})
        $("#binxad-#{adname}").click (e) ->
          window.ga("send", {hitType: "event", eventCategory: "advertisement", eventAction: "ad-click", eventLabel: "#{adname}"})

  renderAdElement: (el, index, klass, adArray) ->
    # check if element is visible, skip rendering if it isn't
    return unless el.offsetWidth > 0 && el.offsetHeight > 0;
    el.classList.add("rendered-ad")
    if adArray[index]
      renderedAd = internalAds[adArray[index]]
      el.innerHTML = "<a href=\"#{renderedAd.href}\" id=\"binxad-#{adArray[index]}\">#{renderedAd.body}</a>"
      adArray[index]


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
