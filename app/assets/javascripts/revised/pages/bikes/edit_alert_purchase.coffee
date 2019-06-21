class BikeIndex.BikesEditAlertPurchase extends BikeIndex
  constructor: ->
    super()
    @$planConfirmationForm = $("#js-confirm-plan-form")
    @initializeEventListeners()

  initializeEventListeners: =>
    @$planConfirmationForm.on "click", "#js-confirm-plan-button", (event) =>
      event.preventDefault()
      @clearAlerts()
      @openStripeForm()

  clearAlerts: () =>
     $(".primary-alert-block .alert").remove()

  openStripeForm: () =>
    $planConfirmationForm = $("#js-confirm-plan-form")
    # Checkout integration custom:
    # https://stripe.com/docs/checkout#integration-custom
    # Use the token to create the charge with a server-side script.
    # You can access the token ID with `token.id`
    handler = window.StripeCheckout.configure
      key: $planConfirmationForm.attr("data-key")
      image: "/apple_touch_icon.png"
      token: (token) ->
        console.log "token"
        console.log token
        $planConfirmationForm.find("#stripe_token").val(token.id)
        $planConfirmationForm.find("#stripe_email").val(token.email)
        $planConfirmationForm.submit()

    amount_cents = +$planConfirmationForm.find("#stripe_amount").val()
    handler.open
      name: "Bike Index"
      description: "Bike Index Theft Alert"
      amount: amount_cents
      email: $planConfirmationForm.data("email")
      allowRememberMe: false
      panelLabel: $planConfirmationForm.data("type")
    return
