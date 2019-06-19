# See https://stripe.com/docs/testing
# for more test card numbers

module StripeHelpers
  TEST_CARD_NUMBERS = {
    visa: "4242424242424242",
    declined: "4000000000000002",
  }.freeze

  def stripe_token(kind = :visa, card_attrs = {})
    if defined?(@stripe_token) && @stripe_token[kind].present?
      return @stripe_token[kind]
    end

    @stripe_token = {} unless defined?(@stripe_token)

    card_attrs = {
      number: TEST_CARD_NUMBERS.fetch(kind),
      exp_month: 12,
      exp_year: 2025,
      cvc: "314",
    }.merge(card_attrs)

    @stripe_token[kind] = Stripe::Token.create(card: card_attrs)
  end
end
