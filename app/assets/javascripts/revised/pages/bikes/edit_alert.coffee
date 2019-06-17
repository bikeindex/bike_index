class BikeIndex.BikesEditAlert extends BikeIndex
  constructor: ->
    super()
    @initializeEventListeners()

  initializeEventListeners: =>
    $("#bikeindex-stripe-bike-alert-form").on "click", ".js-pricing-plan-select", (e) =>
      e.preventDefault()
      amount = $(e.target).data("amount")
      return true unless amount
      @clearAlerts()
      @openStripeForm(amount)
      return false

  clearAlerts: () =>
     $('.primary-alert-block .alert').remove()

  openStripeForm: (amount_cents) =>
    $stripe_form = $('#stripe_form')
    # Checkout integration custom:
    # https://stripe.com/docs/checkout#integration-custom
    # Use the token to create the charge with a server-side script.
    # You can access the token ID with `token.id`
    handler = StripeCheckout.configure
      key: $stripe_form.attr("data-key")
      image: "/apple_touch_icon.png"
      token: (token) ->
        $("#stripe_token").val(token.id)
        $("#stripe_email").val(token.email)
        $("#stripe_form").submit()

    $("#stripe_amount").val(amount_cents)
    handler.open
      name: "Bike Index"
      description: "Bike Index Theft Alert"
      amount: amount_cents
      email: $stripe_form.data("email")
      allowRememberMe: false
      panelLabel: $stripe_form.data("type")
    return
