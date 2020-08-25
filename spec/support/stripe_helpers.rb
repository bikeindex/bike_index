# See https://stripe.com/docs/testing
# for more test card numbers

module StripeHelpers
  TEST_CARD_NUMBERS = {
    visa: "4242424242424242",
    declined: "4000000000000002"
  }.freeze

  def stripe_card(kind = :visa, card_attrs = {})
    {
      number: TEST_CARD_NUMBERS.fetch(kind),
      exp_month: 12,
      exp_year: 2025,
      cvc: "314"
    }.merge(card_attrs)
  end

  def stripe_token_declined
    @declined_card_token ||= Stripe::Token.create(card: stripe_card(:declined))
  end

  def stripe_token_approved
    @approved_card_token ||= Stripe::Token.create(card: stripe_card(:visa))
  end

  alias stripe_token stripe_token_approved
end
