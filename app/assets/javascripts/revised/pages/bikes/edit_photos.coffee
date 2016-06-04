class BikeIndex.BikesEditPhotos extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    @initializeSortablePhotos()
    @initializeImageUploads()

  initializeEventListeners: ->
    $('#public_images').on 'change', '.is_private_check', (e) =>
      @updateImagePrivateness(e)
    $('.edit-bike-submit-wrapper .btn').click (e) ->
      e.preventDefault()
      location.reload(true)

  initializeImageUploads: ->
    initializeSortablePhotos = @initializeSortablePhotos
    finished_upload_template = $('#image-upload-finished-template').html()
    Mustache.parse(finished_upload_template)
    $('#new_public_image').fileupload
      dataType: "script"
      add: (e, data) ->
        types = /(\.|\/)(gif|jpe?g|png|tiff?)$/i
        file = data.files[0]
        $('#public_images').sortable('disable')
        if types.test(file.type) || types.test(file.name)
          data.context = $("<div class='upload'><p><em>#{file.name}</em></p><progress class='progress progress-info'>0%</progress></div>")
          $('#new_public_image').append(data.context)
          data.submit()
        else
          window.BikeIndexAlerts.add('error', "#{file.name} is not a gif, jpeg, or png image file")
      progress: (e, data) ->
        if data.context
          progress = parseInt(data.loaded / data.total * 95, 10) # Multiply by 95, so that it doesn't look done, since progress doesn't work.
          data.context.find('.progress').text(progress + '%')
      done: (e, data) ->
        initializeSortablePhotos()
        file = data.files[0]
        $.each(data.files, (index, file) ->
          data.context.addClass('finished_upload')
            .html(Mustache.render(finished_upload_template, file)).fadeOut()
          )

  initializeSortablePhotos: ->
    $sortable_container = $('#public_images')
    $sortable_container.sortable('destroy') # In case we're reinitializing it
    pushImageOrder = @pushImageOrder
    $sortable_container.sortable
      onDrop: ($item, container, _super) ->
        # Push image order
        pushImageOrder($sortable_container)
        # Run the things we're expected to run
        _super($item, container)

  pushImageOrder: ($sortable_container) ->
    url_target = $sortable_container.data('orderurl')
    sortable_list_items = $sortable_container.children('li')
    # This is a list comprehension for the list of all the sortable items, to make an array
    array_of_photo_ids = ($(list_item).prop('id') for list_item in sortable_list_items)
    new_item_order = 
      list_of_photos: array_of_photo_ids
    # list_of_items is an array containing the ordered list of image_ids
    # Then we post the result of the list comprehension to the url to update
    $.post(url_target, new_item_order)

  updateImagePrivateness: (e) ->
    $target = $(e.target)
    is_private = $target.prop('checked')
    id = $target.parents('.edit-photo-display-list-item').prop('id')
    url_target = "#{$('#public_images').data('imagesurl')}/#{id}/is_private"
    $.post(url_target, {is_private: is_private})
