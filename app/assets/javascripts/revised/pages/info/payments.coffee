class BikeIndex.Payments extends BikeIndex
  constructor: ->
    # Make the body at least as tall as the window
    unless $('body').outerHeight() > $(window).height()
      $('body').css('height', "#{$(window).height()}px")
    @initializeEventListeners()

  initializeEventListeners: ->
    $('#bikeindex-stripe-initial-form').submit (e) =>
      @submitDonation()
      return false
    $('.amount-list a').click (e) =>
      @selectPaymentOption(e)
    $('.amount-list input').focus (e) =>
      @selectPaymentOption(e)

  # Returns null if there isn't a valid value selected
  getAmountSelected: ->
    unless $('.amount-list .active').length > 0
      window.BikeIndexAlerts.add('info', 'Please select or enter an amount')
      return null
    $active = $('.amount-list .active')
    # Return the button amount if an arbitrary amount isn't entered
    return $active.data('amount') unless $active.attr('id') == 'arbitrary-amount'
    amount = parseFloat($active.val())
    # Return the entered amount if it's greater than 0
    return amount if amount > 0
    window.BikeIndexAlerts.add('info', 'Please enter a number')
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
    if $stripe_form.data('type') == 'Pay'
      description = 'Payment to Bike Index'
    else
      description = 'Donate to Bike Index'

    $('#stripe_amount').val(amount_cents)
    handler.open
      name: 'Bike Index'
      description: description
      amount: amount_cents
      email: $stripe_form.attr('data-email')
      allowRememberMe: false
      panelLabel: $stripe_form.data('type')
    return
