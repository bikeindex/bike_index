# frozen_string_literal: true

module MarketplaceFees
  extend Functionable

  PLATFORM_FEE_RATE = Rational(9, 100)
  # The same number in every currency, not converted from USD
  PLATFORM_FEE_CAP_CENTS = 69_00
  # A service fee charged on every payment method
  PROCESSING_FEE_RATE = Rational(3, 100)

  def calculate(item_amount_cents:, shipping_amount_cents: 0, boxing_amount_cents: 0, currency: nil)
    currency_slug = Currency.new(currency || Currency.default.slug).slug
    raise ArgumentError, "Unknown currency: #{currency}" if currency_slug.blank?

    item, shipping, boxing = [item_amount_cents, shipping_amount_cents, boxing_amount_cents].map(&:to_i)
    raise ArgumentError, "Amounts can't be negative" if [item, shipping, boxing].any?(&:negative?)

    subtotal_cents = item + shipping + boxing
    processing_fee_cents = (subtotal_cents * PROCESSING_FEE_RATE).round
    platform_fee_cents = [(item * PLATFORM_FEE_RATE).round, PLATFORM_FEE_CAP_CENTS].min

    {
      currency: currency_slug,
      item_amount_cents: item,
      shipping_amount_cents: shipping,
      boxing_amount_cents: boxing,
      processing_fee_cents:,
      buyer_total_cents: subtotal_cents + processing_fee_cents,
      platform_fee_cents:,
      seller_payout_cents: item - platform_fee_cents,
      shop_payout_cents: boxing,
      shipping_cost_cents: shipping,
      bike_index_cents: platform_fee_cents + processing_fee_cents
    }
  end
end
