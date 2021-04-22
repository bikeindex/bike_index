class BikeIndex.StolenBikeListing extends BikeIndex
  constructor: ->
    new BikeIndex.BikeSearchBar
    new BikeIndex.BikeBoxes
    window.photoModalOpen = false
    # Expand the text on click
    $(".listing-text-expand-link").click (e) ->
      e.preventDefault()
      $target = $(e.target)
      $target.css("display", "none")
      $expander = $($target.attr("href"))
      $expander.slideDown 'fast', ->
        $expander.addClass("listing-text-shown")
        $expander.css("display", "inline-block")

    $(".listing-images a").click (e) =>
      @clickPhoto(e)

    # Rotate photos on arrow key presses
    $(document).keyup (e) =>
      @rotatePhotosOrCloseModal(e)

    # On modal hide
    $(document).on 'hide.bs.modal', ->
      window.photoModalOpen = false
      window.photoExpandedId = null
      return true

    # delegated close catcher, to make sure modals can close
    $("body").on "click", ".modal .close", (e) ->
      # potentially having trouble closing modals, try to fix it
      $(e.target).parents(".modal").modal("hide")

  clickPhoto: (e) ->
    e.preventDefault() # Might want to make it not prevent default sometimes...
    $target = $(e.target)
    $target = $target.parents("a") unless $target.is("a")
    return true unless $target.is("a") # Because otherwise, everything breaks
    @openPhotoModal($target.attr('id'), $target.attr("href"))

  # If href isn't passed, it's assumed we aren't sure that the photo is present
  openPhotoModal: (id, href) ->
    window.photoExpandedId = id
    window.photoModalOpen = true
    modal_id = "#{id}-modal"
    modal_html = "<div class='modal fade stolen-listing-photo-modal' id='#{modal_id}'><div class='modal-dialog' role='document'><div class='modal-content'>"
    modal_html += "<div class='modal-title'><button class='close' 'aria-label'='Close' 'data-dismiss'='modal' type='button'>&times;</button></div>"
    modal_html += "<a href='#{href}'><img src='#{href}'></a>"
    modal_html += "</div></div></div>"
    $("#stolen_bike_listings_index").append(modal_html)
    $("##{modal_id}").modal("show")

  # direction == forward or backward
  lookupPhoto: (direction) ->
    return true unless window.photoExpandedId # Failsafe, ensure the modal is still open
    ids = window.photoExpandedId.split("-").map (s) -> parseInt(s, 10)
    currentListingId = ids[0]
    photoIndex = ids[1]
    # console.log(direction, currentListingId, photoIndex)
    if direction == "forward"
      targetPhotoIndex = photoIndex + 1
    else
      targetPhotoIndex = photoIndex - 1
    if targetPhotoIndex < 0
      console.log("First photo, can't go before it!")
      return true

    targetPhotoId = "#{currentListingId}-#{targetPhotoIndex}"
    $targetPhoto = $("##{targetPhotoId}")
    unless $targetPhoto.length
      console.log("photo not found (probably last photo) - #{targetPhotoId}")
      return true
    # Hide modal, or things get wacky
    $('.modal').modal('hide')
    @openPhotoModal(targetPhotoId, $targetPhoto.attr("href"))

  # similar to BikeIndex.BikesShow rotatePhotosOnArrows
  rotatePhotosOrCloseModal: (event) ->
    return true unless window.photoModalOpen
    if event.keyCode == 27 # Escape key
      $('.modal').modal('hide')
    else if event.keyCode == 39
      @lookupPhoto("forward")
    else if event.keyCode == 37
      @lookupPhoto("backward")
    return true
