class BikeIndex.BikesEditPhotos extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    @initializeSortablePhotos($('#public_images'))

  initializeEventListeners: ->
    pagespace = @

  initializeSortablePhotos: ($sortable_container) ->
    pushImageOrder = @pushImageOrder
    $sortable_container.sortable
      onDrop: ($item, container, _super) ->
        # Push image order
        pushImageOrder($sortable_container)
        # Run the things we're expected to run
        _super($item, container)

  pushImageOrder: ($sortable_container) ->
    console.log 'party'
    url_target = $sortable_container.data('orderurl')
    sortable_list_items = $sortable_container.children('li')
    # This is a list comprehension for the list of all the sortable items, to make an array
    array_of_photo_ids = ($(list_item).attr('id') for list_item in sortable_list_items)
    new_item_order = 
      list_of_photos: array_of_photo_ids
    # list_of_items is an array containing the ordered list of image_ids
    # Then we post the result of the list comprehension to the url to update
    console.log new_item_order
    $.post(url_target, new_item_order)
