class @AdDisplayer
  photo_ads = ['right300x600']
  other_ads = ['top468x60']

  iota_ad = '<h3><a href="https://bikeindex.org/news/iota---a-tiny-tracker-with-huge-potential">Bike Index Approved:</a></h3>' +
                   "<a href=\"http://iotatracker.refr.cc/bikeindex\" onclick=\"trackOutboundLink('http://iotatracker.refr.cc/bikeindex'); return false;\"><img src=\"/ads/iota-square.jpg\" alt=\"Iota Tracker\"></a>"

  lemonade_ad = ''
  lemonade_location_matches = ['california', 'ca', 'ny', 'new york', 'nj', 'new jersey', 'il', 'illinois']

  constructor: ->
    for id in photo_ads
      @photoAd(id) if document.getElementById(id)

  photoAd: (unit) ->
    $('.content-nav-group:last').addClass('additional-ad-space')
    $("##{unit}").html([@geolocatedAd(), iota_ad].join(''))
      .addClass('rendered-ad photo-ad')

  geolocatedAd: ->
    # Wrap the string in blank space so it's possible to check for non word chars
    location = " #{localStorage.getItem('location').toLowerCase()} "
    for match in lemonade_location_matches
      # Check if the matching strings are separate words in the location string
      expression = ///[^\w]#{match}[^\w]///
      return lemonade_ad if location.match(///[^\w]#{match}[^\w]///)
    # return an empty string if there aren't any matches
    ''

  getAd: (unit) ->
    ad_body = '<ins class="adsbygoogle" style="display:block" data-ad-client="ca-pub-8140931939249510" data-ad-slot="7159478183" data-ad-format="auto"></ins>'
    $("##{unit}").html(ad_body).addClass('rendered-ad')
    (adsbygoogle = window.adsbygoogle || []).push({})