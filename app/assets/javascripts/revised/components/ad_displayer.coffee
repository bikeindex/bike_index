class @AdDisplayer
  photo_ads = ['right300x600'] 
  other_ads = ['top468x60']

  constructor: ->
    for id in photo_ads
      @photoAd(id) if document.getElementById(id)

  photoAd: (unit) ->
    ad_body = '<h3><a href="https://bikeindex.org/news/iota---a-tiny-tracker-with-huge-potential">Bike Index Approved:</a></h3>' +
      "<a href=\"http://iotatracker.refr.cc/bikeindex\" onclick=\"trackOutboundLink('http://iotatracker.refr.cc/bikeindex'); return false;\"><img src=\"/ads/iota-square.jpg\" alt=\"Iota Tracker\"></a>"
    $('.content-nav-group:last').addClass('additional-ad-space')
    $("##{unit}").html(ad_body).addClass('rendered-ad photo-ad')

  getAd: (unit) ->
    ad_body = '<ins class="adsbygoogle" style="display:block" data-ad-client="ca-pub-8140931939249510" data-ad-slot="7159478183" data-ad-format="auto"></ins>'
    $("##{unit}").html(ad_body).addClass('rendered-ad')
    (adsbygoogle = window.adsbygoogle || []).push({})