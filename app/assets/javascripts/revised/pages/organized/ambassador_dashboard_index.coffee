class BikeIndex.OrganizedAmbassadorDashboardIndex extends BikeIndex
  constructor: ->
    super()
    @initializeEventListeners()

  initializeEventListeners: ->
    $('#js-task-assignments').on 'click', 'input', (event) ->
      $input = $(event.target)
      $.ajax
        type: "PUT"
        url: $input.data("update-url")
        contentType: "application/json"
        dataType: "json"
        data: JSON.stringify
          id: $input.data("ambassador-task-assignment-id")
          completed: $input.is(":checked")
        error: (xhr) -> console.error(JSON.parse(xhr.responseText))
