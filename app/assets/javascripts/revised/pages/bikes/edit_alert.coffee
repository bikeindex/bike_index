class BikeIndex.BikesEditAlert extends BikeIndex
  constructor: ->
    super()
    @$planSelectionForm = $('#js-select-plan-form')
    @initializeEventListeners()

  initializeEventListeners: =>
    @$planSelectionForm.on "click", ".js-plan-select", (event) =>
      @highlightSelectedPlan(event)

  highlightSelectedPlan: (event) =>
    third = event.target.offsetWidth / 3
    click_in_center_third = Math.ceil(third) < event.offsetX < Math.floor(third * 2)
    if not click_in_center_third
      return false

    # clear selections
    @$planSelectionForm.find(".js-plan-container").removeClass("selected")
    @$planSelectionForm.find(".js-plan-select").removeClass("selected")

    # highlight selected plan
    $footer = $(event.target)
    $footer.addClass("selected")
    $selectedPlan = $footer.closest(".js-plan-container")
    $selectedPlan.addClass("selected")

    # set selected plan
    selected_plan_id = $footer.data("theft-alert-plan-id")
    @$planSelectionForm.find("#selected_plan_id").val(selected_plan_id)
