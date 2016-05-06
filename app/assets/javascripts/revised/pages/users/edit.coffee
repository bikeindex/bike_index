class BikeIndex.UsersEdit extends BikeIndex
  constructor: ->
    $personal_fields = $('.sharing-collapser')
    for field in $personal_fields
      $field = $(field)
      show_field = $field.find('input:checked').val()
      if show_field == 'true'
        $($field.data('target')).collapse('show')

    $('.sharing-collapser input').change ->
      collapser = $(@).parents('.sharing-collapser').data('target')
      $(collapser).collapse('toggle')