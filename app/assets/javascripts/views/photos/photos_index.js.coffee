class BikeIndex.Views.PhotosIndex extends Backbone.View
    
  initialize: ->
    @initializeFlipPhotos()

  initializeFlipPhotos: ->
    size = ($('#photo-page').width() - 1)/10
    $('#photo-page .bike-photo, #photo-page .front, #photo-page .back, #photo-page .front-behind')
      .css('width', size)
      .css('height', size)
    # Set the delay so that the images wait till after the header fades in
    # then run different while statements for each line
    delay = 1000
    photo_numbers = [0..$('.bike-photo').length]
    console.log(photo_numbers)
    for num in photo_numbers
      delay = delay + (200*Math.random())
      @photoFlip(num, delay)
      

  photoFlip: (photo_number, delay) ->
    if $("#photo#{photo_number}").length > 0
      img_src = $("#photo#{photo_number} .back .img-location").text()
      # console.log(img_src)
      $("#photo#{photo_number} .back").html("<img src='#{img_src}'>")
      setTimeout ( ->
        $("#photo#{photo_number}").fadeTo(200, 1)
        setTimeout ( -> 
          $("#photo#{photo_number}").addClass('uncover')
        ), 300
        setTimeout ( -> 
          # $("#photo#{photo_number} .front-behind").fadeIn()
          $("#photo#{photo_number} .front-behind").append("<img src='#{img_src}'>").fadeIn()
        ), 900
      ), delay