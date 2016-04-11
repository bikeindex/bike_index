class BikeIndex.FormWell extends BikeIndex
  constructor: ->
    # Enable optional form update buttons
    new BikeIndex.OptionalFormUpdate
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
