class BikeIndex.InfoSupportTheIndex extends BikeIndex
  constructor: ->
    @initializeEventListeners()

  initializeEventListeners: ->
    $('#bikeindex-stripe-initial-form').submit (e) =>
      @openStripeForm()
      return false
    $('.amount-list a').click (e) =>
      @selectPaymentOption(e)
    $('.amount-list input').focus (e) =>
      @selectPaymentOption(e)

  # Returns null if there isn't a valid value selected
  getAmountSelected: (alert) ->
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

  openStripeForm: ->
    amount = @getAmountSelected()
    return true unless amount
    # Remove alerts if they're around - because we've got a value now!
    $('.primary-alert-block .alert').remove()
    console.log amount

  oldOpenStripeForm: (e) ->
    e.preventDefault()
    selected_opt = $('.payment-types-list .active')
    root = $('#stripe_form')
    # Use the token to create the charge with a server-side script.
    # You can access the token ID with `token.id`

    handler = StripeCheckout.configure(
      key: root.attr('data-key')
      image: '/apple_touch_icon.png'
      token: (token) ->
        $('#stripe_token').val(token.id)
        $('#stripe_email').val(token.email)
        $('#stripe_form').submit()
    )

    if selected_opt.attr('data-arbitrary') > 0
      amount = selected_opt.find('input').val() * 100
      desc = "charge $#{amount/100.00}"
    else
      amount = selected_opt.attr('data-amount')
      desc = selected_opt.find('h3').text()

    $('#stripe_amount').val(amount)
    $('#stripe_subscription').val(selected_opt.attr('data-subscription'))
    $('#stripe_plan').val(selected_opt.attr('data-plan'))
    handler.open
      name: 'Bike Index'
      description: desc
      amount: amount
      email: root.attr('data-email')
      allowRememberMe: false
      panelLabel: selected_opt.attr('data-label')
    return


  selectPaymentOption: (e) ->
    $target = $(e.target)
    e.preventDefault()
    $('.amount-list .active').removeClass('active')
    $target.addClass('active')
    

