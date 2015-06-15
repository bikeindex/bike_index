class BikeIndex.Views.BikesShow extends Backbone.View
  events:
    'click #thumbnails .clickable-image': 'clickPhoto'
    'keyup': 'logKey'
    
  initialize: ->
    @setElement($('#body'))
    if $('#claim-ownership-modal').length > 0
      $('#alert-block .alert-error').hide()
      $('#claim-ownership-modal').modal("show")
    @setPhotos()
    if $('.show-bike-edit').length > 0
      height = $('.show-bike-edit').outerHeight()
      $('.global-footer').css('padding-bottom', "#{height+10}px")


  setPhotos: ->
    if $('#thumbnails').length > 0
      @initializePhotoSelector()
      $("#thumbnail-photos li:first-of-type a").addClass('current-thumb')
      that = @
      $(window).scroll ->
        that.prepPhotos()
        $(window).unbind('scroll')
      

  initializePhotoSelector: ->
    setTimeout ( ->
      thumbnailsWidth = $('#thumbnails li').length * $('#thumbnails li:first').outerWidth(true)
      $('#thumbnails').css('width', "#{thumbnailsWidth-10}px")
      if thumbnailsWidth > $('#thumbnail-photos').width()
        $('.bike-photos').addClass('overflown')
     ) , 500

  logKey:(event) ->
    return true unless $('#thumbnail-photos').data('length') > 1
    if event.keyCode == 39
        # Go forward
        pos = parseInt($('#selected-photo .current-photo').data('pos'), 10)
        pos = pos + 1
        pos = 1 if pos > $('#thumbnail-photos').data('length')
        @shiftToPhoto(pos)
    else if event.keyCode == 37
        # Go backward
        pos = parseInt($('#selected-photo .current-photo').data('pos'), 10)
        pos = pos - 1
        pos = $('#thumbnail-photos').data('length') if pos <= 0
        @shiftToPhoto(pos)

  shiftToPhoto: (pos) ->
    targetPhotoID = $("#selected-photo div[data-pos='#{pos}']").attr("id")
    targetPhoto = $("#thumbnail-photos div[data-id='#{targetPhotoID}']")
    @photoFadeOut(targetPhotoID, targetPhoto)

      

  clickPhoto:(event) ->
    event.preventDefault()
    targetPhoto = $(event.target).parents('.clickable-image')
    targetPhotoID = targetPhoto.attr('data-id')
    @photoFadeOut(targetPhotoID, targetPhoto)

  photoFadeOut: (targetPhotoID, targetPhoto) ->
    if $('#video_embed').length > 0
      if targetPhotoID == "video_embed"
        return false
      else
        $('#video_embed').remove() 
        @photoFadeIn(targetPhotoID, targetPhoto)
    $('#selected-photo .current-photo').addClass('transitioning-photo').removeClass('current-photo')
    if targetPhotoID == "video_embed"
      $('#selected-photo').append("""
        <iframe id="video_embed" width="684" height="462" src="#{targetPhoto.data('link')}" frameborder="0" allowfullscreen></iframe>
        """)
    else
      @photoFadeIn(targetPhotoID, targetPhoto)
    return false # Not sure why this is here, so I left it

  injectPhoto: (targetPhotoID, targetPhoto) ->
    $('#selected-photo').append("""
      <div id="#{targetPhotoID}" style="display: none;">
        <img alt="#{targetPhoto.attr('alt')}" src="#{targetPhoto.attr('data-img')}" id="#{targetPhoto.find('img').attr('id')}" data-action="zoom" data-fullsize="#{targetPhoto.data('link')}" class="initially-hidden">
      </div>
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
      $("##{targetPhotoID}, ##{targetPhotoID} img").css('display', 'block')
    else
      @injectPhoto(targetPhotoID, targetPhoto)
    $("##{targetPhotoID}").addClass('current-photo').removeClass('transitioning-photo')
    $("#thumbnail-photos a").removeClass('current-thumb')
    $("#thumbnail-photos a[data-id='#{targetPhotoID}']").addClass('current-thumb')
    setTimeout ( ->
      $('#selected-photo .transitioning-photo').hide()
      $('#selected-photo .transitioning-photo').removeClass('transitioning-photo current-photo')
    ), 900
    
    # some portrait images are too tall. Let's make em smaller
    ideal_height = $(window).height() * 0.75
    if $("#selected-photo .current-photo").height() > ideal_height
      $("##{targetPhotoID} img").css('height', "#{ideal_height}px").css('width', "auto")
    else
      $("##{targetPhotoID} img").css('height', "auto").css('width', "100%")