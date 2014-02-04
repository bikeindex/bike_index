class BikeIndex.Views.AdminOrganizationsEdit extends Backbone.View
    
  initialize: ->
    @setElement($('#body'))
    @adminLocations()
    @loadNotifications()
    $('.chosen-select select').select2()
    
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
      us_val = parseInt($('#us-country-code').text(), 10)
      console.log($(this).closest('fieldset').find('.country_select_container select'))
      $(this).closest('fieldset').find('.country_select_container select').val(us_val)
      $('.chosen-select select').select2()
      
  loadNotifications: ->
    $('#show_notification a').click (e) ->
      e.preventDefault()
      $('#bike-notification').collapse('show')
      $('#show_notification a').fadeOut()
