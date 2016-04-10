class BikeIndex.FormWell extends BikeIndex
  constructor: ->
    # Enable popovers
    placement = @popoverPlacement
    $('[data-toggle="popover"]').popover
      html: true
      placement: placement

  popoverPlacement: ->
    # When $grid-breakpoint-sm or less, do to the left so we don't overflow
    if window.innerWidth < 544
      'left'
    else
      'top'
