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

    # $("body").on "click", ".purchaseAlert", (event) =>
    #   event.preventDefault()
    #   @clearAlerts()
    #   # @openStripeForm()

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
    # clear selections
    @$alertForm.find(".js-plan-container").removeClass("selected")

    $target = $(event.target)
    unless $target.hasClass("js-plan-container")
      $target = $target.parents(".js-plan-container")

    console.log($target)
    $target.addClass("selected")
    selected_plan_id = $target.attr("data-id")

    # # highlight selected plan
    # $footer = $(event.target)
    # $footer.addClass("selected")
    # $selectedPlan = $footer.closest(".js-plan-container")
    # $selectedPlan.addClass("selected")

    # # set selected plan
    # selected_plan_id = $footer.data("theft-alert-plan-id")
    @$alertForm.find("#selected_plan_id").val(selected_plan_id)

  # clearAlerts: () =>
  #    $(".primary-alert-block .alert").remove()


  # openStripeForm: () =>
  #   $selectedPlan = $(".detail-card-container.selected")

  #   price = $selectedPlan.attr("data-cents")
  #   plan_id = $selectedPlan.attr("data-id")

  #   $planConfirmationForm = $("#js-confirm-plan-form")
  #   # Checkout integration custom:
  #   # https://stripe.com/docs/checkout#integration-custom
  #   # Use the token to create the charge with a server-side script.
  #   # You can access the token ID with `token.id`
  #   handler = window.StripeCheckout.configure
  #     key: $planConfirmationForm.attr("data-key")
  #     image: "/apple_touch_icon.png"
  #     token: (token) ->
  #       $planConfirmationForm.find("#stripe_token").val(token.id)
  #       $planConfirmationForm.find("#stripe_email").val(token.email)
  #       $planConfirmationForm.submit()

  #   handler.open
  #     name: "Bike Index"
  #     description: $planConfirmationForm.data("description")
  #     currency: $planConfirmationForm.data("currency")
  #     amount: parseInt(price, 10)
  #     email: $planConfirmationForm.data("email")
  #     allowRememberMe: false
  #     panelLabel: $planConfirmationForm.data("type")
  #   return
