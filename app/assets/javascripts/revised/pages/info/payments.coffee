class BikeIndex.Payments extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    @t = window.BikeIndex.translator("payments");

  initializeEventListeners: ->
    $('#bikeindex-stripe-initial-form').submit (e) =>
      @submitDonation()
      # For giving tuesday modal
      localStorage.setItem("hideGivingTuesdayModal", "true")
      return false
    $('.amount-list a').click (e) =>
      @selectPaymentOption(e)
    $('.amount-list input').focus (e) =>
      @selectPaymentOption(e)

  # Returns null if there isn't a valid value selected
  getAmountSelected: ->
    unless $('.amount-list .active').length > 0
      window.BikeIndexAlerts.add('info', @t("select_or_enter_amount"))
      return null
    $active = $('.amount-list .active')
    # Return the button amount if an arbitrary amount isn't entered
    return $active.data('amount') unless $active.attr('id') == 'arbitrary-amount'
    amount_cents = parseFloat($active.val()) * 100
    # Return the entered amount if it's greater than $1 (Stripe minimum is 0.50)
    return amount_cents if amount_cents > 100
    window.BikeIndexAlerts.add('info', @t('enter_the_minimum_amount'))
    null

  selectPaymentOption: (e) ->
    $target = $(e.target)
    e.preventDefault()
    $('.amount-list .active').removeClass('active')
    $target.addClass('active')

  submitDonation: ->
    amount = @getAmountSelected()
    return true unless amount
    # Remove alerts if they're around - because we've got a value now!
    $('.primary-alert-block .alert').remove()
    is_arbitrary = $('.amount-list input.active').length > 0
    @openStripeForm(is_arbitrary, amount)

  openStripeForm: (is_arbitrary, amount) ->
    amount_cents = amount * 100
    $stripe_form = $('#stripe_form')
    # Checkout integration custom: https://stripe.com/docs/checkout#integration-custom
    # Use the token to create the charge with a server-side script.
    # You can access the token ID with `token.id`
    handler = StripeCheckout.configure(
      key: $stripe_form.attr('data-key')
      image: '/apple_touch_icon.png'
      token: (token) ->
        $('#stripe_token').val(token.id)
        $('#stripe_email').val(token.email)
        $('#stripe_form').submit()
    )

    $('#stripe_amount').val(amount_cents)
    handler.open
      name: 'Bike Index'
      description: $stripe_form.data('description')
      amount: amount_cents
      currency: $stripe_form.data('currency')
      email: $stripe_form.data('email')
      allowRememberMe: false
      panelLabel: $stripe_form.data('type')
    return
