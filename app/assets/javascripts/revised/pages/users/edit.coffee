class BikeIndex.UsersEdit extends BikeIndex
  constructor: ->
    # Important! We can't instantiate FormWell because
    # optional form blocks don't do what they do everywhere else (in email add)
    $personal_fields = $('.sharing-collapser')
    for field in $personal_fields
      $field = $(field)
      show_field = $field.find('input:checked').val()
      if show_field == 'true'
        $($field.data('target')).collapse('show')

    $('.sharing-collapser input').change ->
      collapser = $(@).parents('.sharing-collapser').data('target')
      $(collapser).collapse('toggle')

    @initializeAdditionalEmails()


    $('.avatar-upload-field').change (event) ->
      name = event.target.files[0].name
      $(event.target).parent().find('.file-upload-text').text(name)
      # tmppath = URL.createObjectURL(event.target.files[0])
      # $('.replaced-img').fadeIn('fast').attr 'src', URL.createObjectURL(event.target.files[0])

  initializeAdditionalEmails: ->
    add_email_template = $('#additional-email-template').html()
    Mustache.parse(add_email_template)

    $('#add_additional_email').click (e) ->
      e.preventDefault()
      $('#additional_email_fields').append(Mustache.render(add_email_template))
      $('#additional_email_fields .collapse').collapse('show')

    $('#additional_email_fields').on 'change', '.add-email-field', (e) =>
      @updateAdditionalEmailValues()

    $('#additional_email_fields').on 'click', '.remove-add-email', (e) =>
      $add_email_field = $(e.target).parents('.form-group')
      $add_email_field.collapse('hide')
      window.setTimeout (=>
        $add_email_field.remove()
        @updateAdditionalEmailValues()
      ), 1000

  updateAdditionalEmailValues: ->
    values = $('#additional_email_fields .add-email-field').get().map (i) -> i.value
    $('#user_additional_emails').val(values)