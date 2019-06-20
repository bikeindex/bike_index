class BikeIndex.BikesEditAlert extends BikeIndex
  constructor: ->
    super()
    @initializeEventListeners()

  initializeEventListeners: =>
    $("#bikeindex-stripe-bike-alert-form").on "click", ".js-pricing-plan-select", (e) =>
      e.preventDefault()
      $selectedPlan = $(e.target)
      amount_cents = $selectedPlan.data("amountCents")
      plan_id = $selectedPlan.data("theftAlertPlanId")
      if not amount_cents or not plan_id
        console.error("Missing amount: '#{amount_cents}' or plan_id: '#{plan_id}'")
        return true
      @clearAlerts()
      @openStripeForm(amount_cents, plan_id)
      return false

  clearAlerts: () =>
     $('.primary-alert-block .alert').remove()

  openStripeForm: (amount_cents, selected_plan_id) =>
    $stripe_form = $('#stripe_form')
    # Checkout integration custom:
    # https://stripe.com/docs/checkout#integration-custom
    # Use the token to create the charge with a server-side script.
    # You can access the token ID with `token.id`
    handler = StripeCheckout.configure
      key: $stripe_form.attr("data-key")
      image: "/apple_touch_icon.png"
      token: (token) ->
        $stripe_form.find("#stripe_token").val(token.id)
        $stripe_form.find("#stripe_email").val(token.email)
        $stripe_form.find("#theft_alert_plan_id").val(selected_plan_id)
        $stripe_form.submit()

    $stripe_form.find("#stripe_amount").val(amount_cents)
    handler.open
      name: "Bike Index"
      description: "Bike Index Theft Alert"
      amount: amount_cents
      email: $stripe_form.data("email")
      allowRememberMe: false
      panelLabel: $stripe_form.data("type")
    return
