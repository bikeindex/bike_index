class BikeIndex.StolenBikeListing extends BikeIndex
  constructor: ->
    new BikeIndex.BikeSearchBar
    new BikeIndex.BikeBoxes
    # Expand the text on click
    $(".listing-text-expand-link").click (e) ->
      e.preventDefault()
      $target = $(e.target)
      $target.css("display", "none")
      $expander = $($target.attr("href"))
      $expander.slideDown 'fast', ->
        $expander.addClass("listing-text-shown")
        $expander.css("display", "inline-block")

