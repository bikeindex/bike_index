class BikeIndex.Views.AdminBlogsEdit extends Backbone.View
    
  initialize: ->
    $('#post-date-field input').datepicker('format: mm-dd-yyy')
    $('#public_image_image').attr('name', "public_image[image]")
    @publicImageFileUpload()
    
  publicImageFileUpload: ->
    # runSortableImages = @sortableImages($('#public_images'))
    $('#new_public_image').fileupload
      dataType: "script"
      add: (e, data) ->
        types = /(\.|\/)(gif|jpe?g|png)$/i
        file = data.files[0]
        $('#public_images').sortable('disable')
        if types.test(file.type) || types.test(file.name)
          data.context = $('<div class="upload"><p><em>' + file.name + '</em></p><div class="progress progress-striped active"><div class="bar" style="width: 0%"></div></div></div>')
          $('#new_public_image').append(data.context)
          data.submit()
        else
          alert("#{file.name} is not a gif, jpeg, or png image file")
      progress: (e, data) ->
        if data.context
          progress = parseInt(data.loaded / data.total * 95, 10) # Multiply by 95, so that it doesn't look done, since progress doesn't work.
          data.context.find('.bar').css('width', progress + '%')
      done: (e, data) ->
        # runSortableImages
        file = data.files[0]
        $.each(data.files, (index, file) ->
          data.context.addClass('finished_upload').html("""
              <p><em>#{file.name}</em></p>
              <div class='alert-success'>
                Finished uploading
              </div>
            """).fadeOut('slow')
          )

  # sortableImages:(sortable_container) ->
  #   # run this as soon as the function starts to update any recently uploaded images
  #   @pushImageOrder(sortable_container)
  #   sortable_container.sortable().bind 'sortupdate', (e, ui) =>
  #     # And obviously run it on update too
  #     @pushImageOrder(sortable_container)

  # pushImageOrder: ( sortable_container ) ->
  #   urlTarget = sortable_container.data('order-url')
  #   sortable_list_items = sortable_container.children('li')
  #   # This is a list comprehension for the list of all the sortable items, to make an array
  #   array_of_photo_ids = ($(list_item).attr('id') for list_item in sortable_list_items)
  #   new_item_order = 
  #     list_of_photos: array_of_photo_ids
  #   # list_of_items is an array containing the ordered list of image_ids
  #   # Then we post the result of the list comprehension to the url to update
  #   $.post(urlTarget, new_item_order)