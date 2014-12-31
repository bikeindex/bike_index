class BikeIndex.Views.AdminRecoveries extends Backbone.View
  events:
    'change #all_select':                     'allRecoverySelect'
    'change #stolen_record_recovery_tweet':   'updateTweetLength'
    'keydown #stolen_record_recovery_tweet': 'updateTweetLength'
    'click #use_image_for_display':          'useBikeImageForDisplay'
    
  initialize: ->
    @setElement($('#body'))

  allRecoverySelect: ->
    $('.multipost_checkbox input').prop('checked', $('#all_select').prop('checked'))

  updateTweetLength: ->
    length = $('#stolen_record_recovery_tweet').val().length
    max = $('#tweet-entry').attr('data-length')
    $('#tweet-length').text(max-length)

  useBikeImageForDisplay: (e) ->
    e.preventDefault()
    image_btn = $('#use_image_for_display')
    if image_btn.hasClass('using_bikes')
      $('.avatar-upload').slideDown()
      $('#recovery_display_remote_image_url').val('')
      image_btn.text('Use first image')
    else
      $('.avatar-upload').slideUp()
      $('#recovery_display_remote_image_url').val(image_btn.attr('data-url'))
      image_btn.text('nvrmind')
    image_btn.toggleClass('using_bikes')
