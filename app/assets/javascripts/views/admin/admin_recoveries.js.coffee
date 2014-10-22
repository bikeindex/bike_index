class BikeIndex.Views.AdminRecoveries extends Backbone.View
  events:
    'change #all_select':                     'allRecoverySelect'
    'change #stolen_record_recovery_tweet':   'updateTweetLength'
    'keydown #stolen_record_recovery_tweet': 'updateTweetLength'
    
  initialize: ->
    @setElement($('#body'))

  allRecoverySelect: ->
    $('.multipost_checkbox input').prop('checked', $('#all_select').prop('checked'))

  updateTweetLength: ->
    length = $('#stolen_record_recovery_tweet').val().length
    max = $('#tweet-entry').attr('data-length')
    $('#tweet-length').text(max-length)