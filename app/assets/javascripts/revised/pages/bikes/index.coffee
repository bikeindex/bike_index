class BikeIndex.BikesIndex extends BikeIndex
  constructor: ->
    new BikeIndex.BikeSearchBar
    new BikeIndex.BikeBoxes
    if $('.organized-body').length
      @instantiateOrganizedBikes()

  instantiateOrganizedBikes: ->
    $('.organized-bikes-stolenness-toggle').on 'click', (e) ->
      e.preventDefault()
      stolenness = $('.organized-bikes-stolenness-toggle').attr('data-stolenness')
      $('#stolenness').val(stolenness)
      $('#bikes_search_form').submit()