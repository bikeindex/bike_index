class BikeIndex.FormWell extends BikeIndex
  constructor: ->
    # Enable popovers
    $('[data-toggle="popover"]').popover
      html: true