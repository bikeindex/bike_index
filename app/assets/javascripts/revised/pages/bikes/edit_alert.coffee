class BikeIndex.BikesEditAlert extends BikeIndex
  constructor: ->
    super()
    @$planSelectionForm = $('#js-select-plan-form')
    @$imageSelectionContainer = $('#js-select-image-container')
    @initializeEventListeners()

  initializeEventListeners: =>
    @$planSelectionForm.on "click", ".js-plan-select", (event) =>
      @highlightSelectedPlan(event)
    @$imageSelectionContainer.on "click", ".js-image-select", (event) =>
      $selectedImage = $(event.target).closest(".js-image-select")
      @highlightSelectedImage($selectedImage)
      @setSelectedImageId($selectedImage)
      @previewSelectedImage($selectedImage)

  highlightSelectedImage: ($selectedImage) =>
    $allImages = $selectedImage.siblings(".js-image-select").removeClass("selected")
    $selectedImage.addClass("selected")

  previewSelectedImage: ($selectedImage) =>
    selectedImageUrl = $selectedImage.data("image-url")
    previewImage = "<img src='#{selectedImageUrl}' alt='alert image preview'>"

    # ensure preview container is visible
    $preview = @$imageSelectionContainer.find("#js-selection-preview")
    $preview.removeClass("d-none")

    # display / switch preview image
    $previewImage = $preview.find("#js-selection-preview-image")
    $previewImage.html(previewImage)

  setSelectedImageId: ($selectedImage) =>
    selectedImageId = $selectedImage.data("image-id")
    @$planSelectionForm.find("#selected_bike_image_id").val(selectedImageId)

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
