class BikeIndex.Views.AdminRecoveries extends Backbone.View
  events:
    'change #all_select': 'allRecoverySelect'
    
  initialize: ->
    @setElement($('#body'))

  allRecoverySelect: ->
    $('.multipost_checkbox input').prop('checked', $('#all_select').prop('checked'))