# frozen_string_literal: true

module MarketplaceFees
  extend Functionable

  def calculate(item_amount_cents:, shipping_amount_cents: 0, boxing_amount_cents: 0, currency: nil, schedule: MarketplaceFeeSchedule.current)
    raise ArgumentError, "No marketplace fee schedule" if schedule.blank?

    currency_slug = Currency.find_sym(currency || Currency.default.slug)
    raise ArgumentError, "Unknown currency: #{currency}" if currency_slug.blank?

    item, shipping, boxing = [item_amount_cents, shipping_amount_cents, boxing_amount_cents].map(&:to_i)
    raise ArgumentError, "Amounts can't be negative" if [item, shipping, boxing].any?(&:negative?)

    subtotal_cents = item + shipping + boxing
    processing_fee_cents = (subtotal_cents * schedule.processing_fee_percent.to_r / 100).round
    platform_fee_cents = [(item * schedule.platform_fee_percent.to_r / 100).round, schedule.platform_fee_cap_cents].min

    {
      marketplace_fee_schedule_id: schedule.id,
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
