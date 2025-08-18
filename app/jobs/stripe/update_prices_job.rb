# frozen_string_literal: true

class Stripe::UpdatePricesJob < ApplicationJob
  def perform
    updated_ids = []

    Stripe::Price.list({limit: 100}).each do |price|
      stripe_price = StripePrice.find_by(stripe_id: price.id) || StripePrice.new(stripe_id: price.id)
      new_attributes = {
        currency: price.currency,
        amount_cents: price.unit_amount,
        membership_level: product_membership_level[price.product],
        interval: "#{price.recurring["interval"]}ly",
        live: price.livemode,
        active: active?(price.active, price.livemode)
      }

      # Only create if we know the membership kind
      if new_attributes[:membership_level].present?
        stripe_price.update!(new_attributes)
        updated_ids << stripe_price.id
      end
    end

    StripePrice.where.not(id: updated_ids).each { |stripe_price| stripe_price.update(active: false) }
  end

  private

  # Only mark it active if it's active and the livemode matches current system livemode
  def active?(active, live)
    active && live == STRIPE_LIVE_MODE
  end

  def product_membership_level
    return @product_membership_level if defined?(@product_membership_level)

    membership_products = Stripe::Product.list({active: true, limit: 100})
      .select { it.name.match?(/member/i) }

    @product_membership_level = [
      [membership_products.find { it.name.downcase == "membership" }&.id, :basic],
      [membership_products.find { it.name.match?(/plus|\+/i) }&.id, :plus],
      [membership_products.find { it.name.match?(/patron/i) }&.id, :patron]
    ].to_h
  end
end
