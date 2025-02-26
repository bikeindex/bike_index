# frozen_string_literal: true

class Stripe::UpdatePricesJob < ApplicationJob
  def perform
    Stripe::Price.list({active: true, limit: 100}).each do |price|
      stripe_price = StripePrice.find_by(stripe_id: price.id) || StripePrice.new(stripe_id: price.id)
      new_attributes = {
        currency: price.currency,
        live: price.livemode,
        amount_cents: price.unit_amount,
        membership_level: product_membership_level[price.product],
        interval: "#{price.recurring["interval"]}ly",
        active: true
      }

      # Only create if we know the membership kind
      if new_attributes[:membership_level].present?
        stripe_price.update!(new_attributes)
      end
    end
  end

  private

  def product_membership_level
    return @product_membership_level if defined?(@product_membership_level)

    membership_products = Stripe::Product.list({active: true, limit: 100})
      .select { _1.name.match?(/member/i) }

    @product_membership_level = [
      [membership_products.find { _1.name.downcase == "membership" }&.id, :basic],
      [membership_products.find { _1.name.match?(/plus|\+/i) }&.id, :plus],
      [membership_products.find { _1.name.match?(/patron/i) }&.id, :patron]
    ].to_h
  end
end
