class BikeIndex.Views.BikesShow extends Backbone.View
  events:
    'click .single-bike-photos .clickable-image': 'clickPhoto'
    'keyup': 'logKey'
    
  initialize: ->
    @setElement($('#body'))
    if $('#claim-ownership-modal').length > 0
      $('#alert-block .alert-error').hide()
      $('#claim-ownership-modal').modal("show")

    @initializePhotoSelector()
    @prepPhotos()


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
      if $('#thumbnail-photos').data('length') > 1
        # Go forward
        pos = parseInt($('#selected-photo .current-photo').data('pos'), 10)
        pos = pos + 1
        pos = 1 if pos > $('#thumbnail-photos').data('length')
        @shiftToPhoto(pos)
    else if event.keyCode == 37
      if $('#thumbnail-photos').data('length') > 1
        # Go backward
        pos = parseInt($('#selected-photo .current-photo').data('pos'), 10)
        pos = pos - 1
        pos = $('#thumbnail-photos').data('length') if pos <= 0
        @shiftToPhoto(pos)

  shiftToPhoto: (pos) ->
    targetPhotoID = $("#selected-photo a[data-pos='#{pos}']").attr("id")
    targetPhoto = $("#thumbnail-photos a[data-id='#{targetPhotoID}']")
    @photoFadeOut(targetPhoto, targetPhotoID)

      

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

  injectPhoto: (targetPhotoID, targetPhoto) ->
    $('#selected-photo').append("""
      <a href="#{targetPhoto.data('link')}" target="_blank" id="#{targetPhotoID}" style="display: none;">
        <img alt="#{targetPhoto.attr('alt')}" src="#{targetPhoto.attr('data-img')}" id="#{targetPhoto.find('img').attr('id')}" class="initially-hidden">
      </a>
    """)

  prepPhotos: ->
    $('#thumbnail-photos').data('length',0)
    return true unless $('#thumbnail-photos li').length > 0
    $('#thumbnail-photos').data('length',$('#thumbnail-photos li').length)
    for li, index in $('#thumbnail-photos li')
      targetPhoto = $(li).find('.clickable-image')
      targetPhotoID = targetPhoto.attr('data-id')
      @injectPhoto(targetPhotoID, targetPhoto) unless $("##{targetPhotoID}").length > 0
      i = index + 1
      $("##{targetPhotoID}").attr('data-pos', i)


  photoFadeIn: (targetPhotoID, targetPhoto) ->
    if $("##{targetPhotoID}").length > 0
      $("##{targetPhotoID}").addClass('current-photo')
    else
      @injectPhoto(targetPhotoID, targetPhoto)
      $("##{targetPhotoID}").addClass('current-photo')
    $('#selected-photo .current-photo, #selected-photo .current-photo img').fadeIn('fast')