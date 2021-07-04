class BikeIndex.Payments extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    @t = window.BikeIndex.translator("payments");

  initializeEventListeners: ->
    $('#new-payment-form').submit (e) =>
      return @submitDonation()

    $('.amount-list a').click (e) =>
      @selectPaymentOption(e)

    # If the arbitrary amount is selected (and on keyboard movement), select the appropriate target
    $('.amount-list input').focus (e) =>
      $target = $(e.target)
      if $target.attr("data-amount") || $target.attr("id") == "arbitrary-amount"
        @selectPaymentOption(e)
      true

  # Returns null if there isn't a valid value selected
  getAmountCentsSelected: ->
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
    amount_cents = @getAmountCentsSelected()
    return false unless amount_cents

    # Remove alerts if they're around - because we've got a value now!
    $('.primary-alert-block .alert').remove()
    # We're submitting the form now, so hide the modal
    localStorage.setItem("hideDonationModal", "true")

    $("#new-payment-form #is_arbitrary").val($('.amount-list input.active').length > 0)
    $("#new-payment-form #payment_amount_cents").val(amount_cents)
    true
