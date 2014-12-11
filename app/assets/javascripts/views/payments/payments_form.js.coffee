class BikeIndex.Views.PaymentsForm extends Backbone.View
  events:
    'click #open_stripe_checkout_btn': 'openStripeForm'
    'click .select-payment': 'selectPaymentOption'
    

  initialize: ->
    @setElement($('#body'))

  openStripeForm: (e) ->
    e.preventDefault()
    selected_opt = $('.payment-types-list .active')
    root = $('#stripe_form')
    # Use the token to create the charge with a server-side script.
    # You can access the token ID with `token.id`

    handler = StripeCheckout.configure(
      key: root.attr("data-key")
      image: "/assets/logos/logo_w_bg.png"
      token: (token) ->
        $('#stripe_token').val(token.id)
        $('#stripe_email').val(token.email)
        $('#stripe_form').submit()
    )

    if selected_opt.attr('data-arbitrary') > 0
      amount = selected_opt.find('input').val() * 100
      desc = "Donate $#{amount/100.00}"
    else
      amount = selected_opt.attr('data-amount')
      desc = selected_opt.find('h3').text()

    $('#stripe_amount').val(amount)
    $('#stripe_subscription').val(selected_opt.attr('data-subscription'))
    $('#stripe_plan').val(selected_opt.attr('data-plan'))
    handler.open
      name: "Bike Index"
      description: desc
      amount: amount
      email: root.attr("data-email")
      allowRememberMe: false
      panelLabel: selected_opt.attr('data-label')
    return


  selectPaymentOption: (e) ->
    e.preventDefault()
    $('.payment-types-list a').addClass('unselected').removeClass('active')
    $(e.target).parents('li').find('.select-payment').removeClass('unselected').addClass('active')
