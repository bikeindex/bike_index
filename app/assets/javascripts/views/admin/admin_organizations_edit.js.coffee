class BikeIndex.Views.AdminOrganizationsEdit extends Backbone.View
    
  initialize: ->
    @setElement($('#body'))
    @adminLocations()
    
  adminLocations: ->
    $('form').on 'click', '.remove_fields', (event) ->
      # We don't need to do anything except slide the input up, because the label is on it.
      $(this).closest('fieldset').slideUp()
      # event.preventDefault()
    $('form').on 'click', '.add_fields', (event) ->
      time = new Date().getTime()
      regexp = new RegExp($(this).data('id'), 'g')
      $(this).before($(this).data('fields').replace(regexp, time))
      event.preventDefault()