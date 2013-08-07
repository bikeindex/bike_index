class BikeIndex.Views.UsersEdit extends Backbone.View
   
  initialize: ->
    @setElement($('#body'))
    @loadUserForm()

  loadUserForm: ->
    personal_fields = $('.sharing-collapser')
    for field in personal_fields
      show_field = $(field).find('input:checked').val()
      if show_field == 'true'
        $($(field).data('target')).collapse('toggle')
    $('.sharing-collapser input').change ->
      collapser = $(@).parents('.sharing-collapser').data('target')
      $(collapser).collapse('toggle')