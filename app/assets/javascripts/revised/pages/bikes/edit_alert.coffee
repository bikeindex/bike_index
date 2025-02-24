class BikeIndex.BikesEditAlert extends BikeIndex
  constructor: ->
    super()
    @$alertForm = $('#alert-form')
    @$imageSelectionContainer = $('#js-select-image-container')
    @initializeEventListeners()

  initializeEventListeners: =>
    @$alertForm.on "click", ".js-plan-container", (event) =>
      @selectPlan(event)

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
    $previewImage = @$imageSelectionContainer.find("#js-selection-preview-image img")
    $previewImage.attr("src", selectedImageUrl)

  setSelectedImageId: ($selectedImage) =>
    selectedImageId = $selectedImage.data("image-id")
    @$alertForm.find("#selected_bike_image_id").val(selectedImageId)

  selectPlan: (event) =>
    @$alertForm.find(".js-plan-container").removeClass("selected")

    $target = $(event.target)
    unless $target.hasClass("js-plan-container")
      $target = $target.parents(".js-plan-container")

    $target.addClass("selected")
    @$alertForm.find("#promoted_alert_plan_id").val($target.attr("data-id"))
