class BikeIndex.Views.AdminBlogsEdit extends Backbone.View

  events:
    'click #change_published_date': 'editDate'

    
  initialize: ->
    @setElement($('#body'))
    $('#public_image_image').attr('name', "public_image[image]")
    @publicImageFileUpload()
    $('.edit_blog').areYouSure()
    
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


  editDate: (event) ->
    event.preventDefault()
    unless $('#blog-date').is(":visible")
      target = $(event.target)
      date = target.attr('data-date')
      $('#blog-date').slideDown()
      $('#post-date-field input').val(date).attr("data-date-format","mm-dd-yyyy")
      $('#post-date-field input').datepicker('format: mm-dd-yyy')
      # , value: @blog.published_at.strftime("%m-%d-%Y"), required: true, data: { :'date-format' => "mm-dd-yyyy" }


