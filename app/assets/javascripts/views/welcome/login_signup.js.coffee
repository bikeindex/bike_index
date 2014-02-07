class BikeIndex.Views.LoginSignup extends Backbone.View
    
  initialize: ->
    @initializeFlipPhotos()

  initializeFlipPhotos: ->
    $("#never-block").fadeTo(900, 1)
    if $('body').width() > 768
      size = ($('#photos-flip').width() - 1)/6
      $('#photos-flip .bike-photo, #photos-flip .front, #photos-flip .back, #photos-flip .front-behind')
        .css('width', size)
        .css('height', size)
      # Set the delay so that the images wait till after the header fades in
      # then run different while statements for each line
      delay = 1000
      photo_numbers = [0..17]
      
      if $('#new_user').length > 0
        Array::push.apply photo_numbers, [18..23]
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