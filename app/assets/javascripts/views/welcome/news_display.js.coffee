class BikeIndex.Views.NewsDisplay extends Backbone.View
    
  initialize: ->
    @setElement($('#body'))
    @setAds()

  setAds: ->
    for party in $('.party-blck:visible')
      party = $(party)
      ad = """
        <ins class="adsbygoogle" style="height:#{party.attr('data-height')};max-width: 100%;width:#{party.attr('data-width')};" data-ad-client="ca-pub-8140931939249510" data-ad-slot="#{party.attr('data-slot')}"></ins>
        <script>(adsbygoogle = window.adsbygoogle || []).push({});</script>
       """
      party.append(ad)
