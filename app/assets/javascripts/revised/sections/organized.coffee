class BikeIndex.Organized extends BikeIndex
  constructor: ->
    # Only on the edit organization page, but no real reason to create another
    # coffeescript file
    $('.avatar-upload-field').change (event) ->
      name = event.target.files[0].name
      $(event.target).parent().find('.file-upload-text').text(name)

    # On the stickers#index page, submit search after update
    # click rather than change b/c this version of bootstrap blocks bubbling up change events from btn-groups :/
    $("#organized-bike-code-claimedness .btn").on "click", (event) ->
       window.setTimeout (->
        $(".stickers-form").submit()
       ), 250
