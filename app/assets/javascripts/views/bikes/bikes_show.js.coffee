class BikeIndex.Views.BikesShow extends Backbone.View
  events:
    'click .single-bike-photos .clickable-image': 'clickPhoto'
    # 'keyup': 'logKey'
    
  initialize: ->
    @setElement($('#body'))
    if $('#claim-ownership-modal').length > 0
      $('#alert-block .alert-error').hide()
      $('#claim-ownership-modal').modal("show")

    @initializePhotoSelector()


  initializePhotoSelector: ->
    setTimeout ( ->
      if $('#thumbnails li').css('float') == "none"
        li_size = $('#thumbnails li:first').height()
        if (li_size * $('#thumbnail-photos li').length) > $('#thumbnail-photos').height()
          $('#thumbnail-photos').addClass('overflown')
      else
        thumbnailsWidth = $('#thumbnails li').length * ($('#thumbnails li:first').width() + 20)
        $('#thumbnails').addClass('horizontal')
        $('#thumbnails.horizontal').width(thumbnailsWidth + 20)
        if thumbnailsWidth > $('#thumbnail-photos').width()
          $('#thumbnail-photos').addClass('overflown')
     ) , 500
    
    $(window).resize ->
      if $('#thumbnails li').css('float') == "left"
        unless $('#thumbnails').hasClass('horizontal')
          $('#thumbnails').addClass('horizontal')
          $('#thumbnails.horizontal').width( ($('#thumbnails li').length * ($('#thumbnails li:first').width() + 20)) + 30)
      else
        if $('#thumbnails').hasClass('horizontal')
          $('#thumbnails').removeClass('horizontal')
          $('#thumbnails').width('100%')

  logKey:(event) ->
    if event.keyCode == 39
      # Go forward
      c_photo = $('#selected-photo .current-photo img').attr('id')
      c_photo = c_photo.split('|')
      c_photo = parseInt(c_photo[1], 10)
      # console.log(c_photo)
    if event.keyCode == 37
      # Go left
      current_photo = $('#selected-photo .current-photo img').attr('id')
      current_photo = parseInt(current_photo, 10)
      

  clickPhoto:(event) ->
    event.preventDefault()
    targetPhoto = $(event.target).parents('.clickable-image')
    targetPhotoID = targetPhoto.attr('data-id')
    @photoFadeOut(targetPhoto, targetPhotoID)

  photoFadeOut: (targetPhoto, targetPhotoID) ->
    if $('#video_embed').length > 0
      if targetPhotoID == "video_embed"
        return false
      else
        $('#video_embed').remove() 
        @photoFadeIn(targetPhotoID, targetPhoto)
    
    $('#selected-photo .current-photo').fadeOut(
      'fast', =>
        $('#selected-photo .current-photo').hide().removeClass('current-photo')
        if targetPhotoID == "video_embed"
          $('#selected-photo').append("""
            <iframe id="video_embed" width="684" height="462" src="#{targetPhoto.data('link')}" frameborder="0" allowfullscreen></iframe>
            """)
        else
          @photoFadeIn(targetPhotoID, targetPhoto)
      )
    return false # Not sure why this is here, so I left it


  photoFadeIn: (targetPhotoID, targetPhoto) ->
    if $("##{targetPhotoID}").length > 0
      $("##{targetPhotoID}").addClass('current-photo')
    else
      $('#selected-photo').append("""
        <a href="#{targetPhoto.data('link')}" target="_blank" id="#{targetPhotoID}" class="current-photo">
          <img alt="#{targetPhoto.attr('alt')}" src="#{targetPhoto.attr('data-img')}" id="#{targetPhoto.find('img').attr('id')}" class="initially-hidden">
        </a>
        """)
    $('#selected-photo .current-photo, #selected-photo .current-photo img').fadeIn('fast')