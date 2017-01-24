class @AdDisplayer
  ad_units = ['right300x600'] # 'top468x60'

  constructor: ->
    for id in ad_units
      @getAd(id) if document.getElementById(id)

  getAd: (unit) ->
    ad_body = '<ins class="adsbygoogle" style="display:block" data-ad-client="ca-pub-8140931939249510" data-ad-slot="7159478183" data-ad-format="auto"></ins>'
    $("##{unit}").html(ad_body).addClass('rendered-ad')
    (adsbygoogle = window.adsbygoogle || []).push({})