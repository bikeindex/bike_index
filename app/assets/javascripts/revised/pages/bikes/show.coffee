class BikeIndex.BikesShow extends BikeIndex
  constructor: ->
    window.bike_photos_loaded = false
    if $('.bike-edit-overlay').length > 0
      @showBikeEditOverlay()

    # Show the "claim bike" modal if it's present
    $('#claim-bike-modal').modal('show') if document.getElementById('claim-bike-modal')

    # Hide the message button after click
    $('#write_them_a_message').click (e) ->
      $target = $(e.target).parents('#write_them_a_message')
      if $target.data('redirect')
        window.location = $target.data('redirect')
        return false
      else
        $('#write_them_a_message').collapse('toggle')

    if document.getElementById('thumbnails')
      # There are only event listeners if there are thumbnails
      @initializeEventListeners()
      # Initialize switching between thumbnails if they're present
      @initializeThumbnailSwitching()

    # Shrink the main image if it's too tall (and it exists)
    $current_photo = $('#selected-photo .current-photo')
    @setIdealImageHeight() if $current_photo.length > 0

  initializeEventListeners: ->
    # Update photo on click
    $('#thumbnails .clickable-image').click (e) =>
      @clickPhoto(e)
    # Rotate photos on arrow key presses
    $(document).keyup (e) =>
      @rotatePhotosOnArrows(e)
    # If the window scrolls, load photos, so there isn't a delay when clicking
    # on them - and so we don't load them unless there is interaction with the page
    $(window).scroll =>
      @loadPhotos()
      $(window).unbind('scroll')

  showBikeEditOverlay: ->
    # Affix the edit menu to the page - broken in chrome, so we're using position fixed
    # $('.bike-edit-overlay').Stickyfill()
    # Add class to footer so it's still visible
    $('.primary-footer .terms-and-stuff').addClass('bike-show-page-with-edit-overlay')

  initializeThumbnailSwitching: ->
    # Set up the template for injecting photos
    window.current_photo_template = $('#current-photo-template').html()
    Mustache.parse(window.current_photo_template)

    # Pause for a moment before setting the thumbnail width, to give css and images
    # a chance to load
    setTimeout ( =>
      @setThumbnailOverflow(@isVerticalLayout())
    ), 500

  isVerticalLayout: ->
    $(window).width() > 768 # grid-breakpoint-md

  setThumbnailOverflow: (is_vertical_layout) ->
    if is_vertical_layout
      $('#thumbnails').css('width', 'auto') # Remove hard-coded width, if it's there
      thumbnails_height = $('#thumbnails li').length * $('#thumbnails li:first').outerHeight(true)
      if thumbnails_height > $('#thumbnail-photos').height()
        $('.bike-photos').addClass('overflown')
    else
      thumbnails_width = $('#thumbnails li').length * $('#thumbnails li:first').outerWidth(true)
      $('#thumbnails').css('width', "#{thumbnails_width}px")
      if thumbnails_width > $('#thumbnail-photos').width()
        $('.bike-photos').addClass('overflown')

  rotatePhotosOnArrows: (event) ->
    if event.keyCode == 39
      # Go forward
      pos = parseInt($('#selected-photo .current-photo').data('pos'), 10)
      pos = pos + 1
      pos = 1 if pos > $('#thumbnail-photos').data('length')
      @shiftToPhoto(pos, true)
    else if event.keyCode == 37
      # Go backward
      pos = parseInt($('#selected-photo .current-photo').data('pos'), 10)
      pos = pos - 1
      pos = $('#thumbnail-photos').data('length') if pos <= 0
      @shiftToPhoto(pos, true)

  shiftToPhoto: (pos, scroll_to_thumb = false) ->
    target_photo_id = $("#selected-photo div[data-pos='#{pos}']").prop('id')
    $target_photo = $("#thumbnail-photos a[data-id='#{target_photo_id}']")
    if target_photo_id
      @photoFadeOut(target_photo_id, $target_photo)
      # Primarily, scrolling is setup to make things better for keyboard navigation
      if scroll_to_thumb and $target_photo.offset() # Ensure we found the element before scrolling
        $thumbs = $('#thumbnail-photos')
        if @isVerticalLayout()
          offset = $target_photo.offset().top - $thumbs.offset().top
          $thumbs.animate
            scrollTop: offset, 'fast'
        else
          # couldn't get this to work correctly :(
          # Plus, this is on small screens, so probs no keyboard anyway
          # offset = $target_photo.offset().left - $thumbs.scrollLeft()
          # $thumbs.animate
          #   scrollLeft: offset, 'fast'
    else
      # We can't find the photos, prolly because they aren't loaded.
      # So load them. Then do nothing or else stuff breaks
      @loadPhotos()

  clickPhoto: (event) ->
    event.preventDefault()
    $target_photo = $(event.target).parents('.clickable-image')
    target_photo_id = $target_photo.attr('data-id')
    @photoFadeOut(target_photo_id, $target_photo)

  photoFadeOut: (target_photo_id, $target_photo) ->
    $('#selected-photo .current-photo').addClass('transitioning-photo').removeClass('current-photo')
    @photoFadeIn(target_photo_id, $target_photo)

  injectPhoto: (target_photo_id, $target_photo) ->
    attrs =
      id: target_photo_id
      alt: $target_photo.attr('alt')
      src: $target_photo.data('img')
      fullsize: $target_photo.data('link')
      image_id: $target_photo.find('img').prop('id')
    $('#selected-photo').append(Mustache.render(window.current_photo_template, attrs))

  loadPhotos: ->
    return true if window.bike_photos_loaded
    return true unless $('#thumbnail-photos li').length > 0
    $('#thumbnail-photos').data('length', $('#thumbnail-photos li').length)
    for li, index in $('#thumbnail-photos li')
      $target_photo = $(li).find('.clickable-image')
      target_photo_id = $target_photo.attr('data-id')
      @injectPhoto(target_photo_id, $target_photo) unless $("##{target_photo_id}").length > 0
      i = index + 1
      $("##{target_photo_id}").attr('data-pos', i)
    window.bike_photos_loaded = true


  photoFadeIn: (target_photo_id, $target_photo) ->
    unless $("##{target_photo_id}").length > 0
      # console.log 'late to the party', target_photo_id, $target_photo
      @injectPhoto(target_photo_id, $target_photo)
      @loadPhotos() # Since photos haven't loaded yet, load them
    $("##{target_photo_id}, ##{target_photo_id} img").css('display', 'block')
    $("##{target_photo_id}").addClass('current-photo').removeClass('transitioning-photo')
    $("#thumbnail-photos a").removeClass('current-thumb')
    $("#thumbnail-photos a[data-id='#{target_photo_id}']").addClass('current-thumb')
    setTimeout ( ->
      $('#selected-photo .transitioning-photo').hide()
      $('#selected-photo .transitioning-photo').removeClass('transitioning-photo current-photo')
    ), 900

    @setIdealImageHeight(target_photo_id)
    @setThumbnailOverflow(@isVerticalLayout())

  setIdealImageHeight: (target_photo_id = null) ->
    target_photo_id ||= $('#selected-photo .current-photo').prop('id')
    # some images are too tall. Let's make em smaller
    ideal_height = $(window).height() * 0.75
    $("##{target_photo_id} img").css('max-height', "#{ideal_height}px").css('width', "auto")
