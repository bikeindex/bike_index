class @AdDisplayer
  photo_ads = ['right300x600']
  other_ads = ['top468x60']

  boomerang_ad = "<a href=\"https://boomerangbike.com/\"><img src=\"/ads/boomerang_v4.jpg\" alt=\"Boomerang\"></a>"

  lemonade_ad = '<h3><a href="https://bikeindex.org/news/bike-index-partners-with-renters-and-homeowners-insurance-company-lemo">Bike Index Approved:</a></h3>' +
                   "<a href=\"https://www.lemonade.com/l/bike-index?utm_medium=partners&utm_source=bike-index&utm_campaign=website\" onclick=\"trackOutboundLink('https://www.lemonade.com/l/bike-index?utm_medium=partners&utm_source=bike-index&utm_campaign=website'); return false;\"><img src=\"https://files.bikeindex.org/partner/Lemonade-Tile.jpg\" alt=\"Lemonade\" style=\"margin-bottom: 30px;\"></a>"

  lemonade_location_matches = ['california', 'ca', 'nevada', 'nv', 'texas', 'tx', 'illinois', 'il', 'ohio', 'oh', 'new york', 'ny', 'new jersey', 'nj', 'rhode island', 'ri']

  constructor: ->
    for id in photo_ads
      @photoAd(id) if document.getElementById(id)

  photoAd: (unit) ->
    $(".content-nav-group:last").addClass("additional-ad-space")
    $("##{unit}").html([@geolocatedAd()].join("")).addClass("rendered-ad photo-ad")

  geolocatedAd: ->
    location = localStorage.getItem('location')
    if location?
      # Wrap the string in blank space so it's possible to check for non word chars
      location = " #{location.toLowerCase()} "
      for match in lemonade_location_matches
        # Check if the matching strings are separate words in the location string
        expression = ///[^\w]#{match}[^\w]///
        return lemonade_ad if location.match(///[^\w]#{match}[^\w]///)
    else
      # Display it anyway, our location tracking is sort of BS
      return lemonade_ad
    # return an empty string if there aren't any matches
    ''

  getAd: (unit) ->
    ad_body = '<ins class="adsbygoogle" style="display:block" data-ad-client="ca-pub-8140931939249510" data-ad-slot="7159478183" data-ad-format="auto"></ins>'
    $("##{unit}").html(ad_body).addClass('rendered-ad')
    (adsbygoogle = window.adsbygoogle || []).push({})