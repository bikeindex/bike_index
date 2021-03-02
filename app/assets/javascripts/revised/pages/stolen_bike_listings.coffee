# Note: only has an index page

class BikeIndex.StolenBikeListings extends BikeIndex
  constructor: ->
    new BikeIndex.BikeSearchBar
    new BikeIndex.BikeBoxes
    console.log("parttty")
