# == Schema Information
#
# Table name: marketplace_orders
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  amount_cents                :integer
#  currency_enum               :integer
#  fulfillment_kind            :integer
#  item_amount_cents           :integer
#  paid_at                     :datetime
#  platform_fee_cents          :integer
#  shipping_amount_cents       :integer
#  shop_fee_cents              :integer
#  status                      :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  buyer_id                    :bigint
#  marketplace_listing_id      :bigint           not null
#  marketplace_partner_shop_id :bigint
#  sale_id                     :bigint
#  seller_id                   :bigint
#  stripe_payment_intent_id    :string
#
# Indexes
#
#  index_marketplace_orders_on_buyer_id                     (buyer_id)
#  index_marketplace_orders_on_marketplace_listing_id       (marketplace_listing_id)
#  index_marketplace_orders_on_marketplace_partner_shop_id  (marketplace_partner_shop_id)
#  index_marketplace_orders_on_sale_id                      (sale_id)
#  index_marketplace_orders_on_seller_id                    (seller_id)
#  index_marketplace_orders_on_status                       (status)
#
class MarketplaceOrder < ApplicationRecord
  include Amountable
  include Currencyable

  STATUS_ENUM = {pending_payment: 0, paid: 1, awaiting_drop_off: 2, dropped_off: 3,
                 in_transit: 4, delivered: 5, completed: 6, cancelled: 7, refunded: 8}.freeze
  FULFILLMENT_KIND_ENUM = {local_pickup: 0, shipped: 1}.freeze

  SHIPPING_STATUSES = %i[awaiting_drop_off dropped_off in_transit delivered].freeze
  ENDED_STATUSES = %i[completed cancelled refunded].freeze

  enum :status, STATUS_ENUM
  enum :fulfillment_kind, FULFILLMENT_KIND_ENUM, prefix: :fulfillment

  belongs_to :marketplace_listing
  belongs_to :buyer, class_name: "User"
  belongs_to :seller, class_name: "User"
  belongs_to :sale
  belongs_to :marketplace_partner_shop

  validates_presence_of :marketplace_listing_id, :status, :fulfillment_kind
  validate :buyer_is_not_seller
  validate :fulfillment_is_available
  validate :status_matches_fulfillment_kind
  validate :shop_present_once_shipping_starts

  before_validation :set_calculated_attributes

  scope :current, -> { where.not(status: ENDED_STATUSES) }

  class << self
    def statuses = STATUS_ENUM.keys.map(&:to_s)

    def fulfillment_kinds = FULFILLMENT_KIND_ENUM.keys.map(&:to_s)
  end

  def ended? = ENDED_STATUSES.include?(status&.to_sym)

  # Shown to the buyer beside the bike's price rather than folded into one opaque total
  def fulfillment_amount_cents
    shipping_amount_cents.to_i + shop_fee_cents.to_i
  end

  private

  def component_amount_cents
    [item_amount_cents, shipping_amount_cents, shop_fee_cents, platform_fee_cents]
      .compact.sum
  end

  def set_calculated_attributes
    self.status ||= :pending_payment
    self.seller_id ||= marketplace_listing&.seller_id
    self.item_amount_cents ||= marketplace_listing&.amount_cents
    # Once paid, the total is what the buyer was charged - a refund adjusts the components
    # without rewriting it
    self.amount_cents = component_amount_cents unless paid_at.present? && amount_cents.present?
  end

  def buyer_is_not_seller
    return if buyer_id.blank? || buyer_id != seller_id

    errors.add(:buyer_id, "can't buy your own listing")
  end

  # Only on the way in: re-deciding it on each status transition reloads the listing and its bike
  def fulfillment_is_available
    return unless new_record? || fulfillment_kind_changed?
    return unless fulfillment_shipped?
    return if marketplace_listing&.shippable?

    errors.add(:fulfillment_kind, "isn't available for this listing")
  end

  def shipping_status? = SHIPPING_STATUSES.include?(status&.to_sym)

  def status_matches_fulfillment_kind
    return unless fulfillment_local_pickup? && shipping_status?

    errors.add(:status, "doesn't apply to a local pickup")
  end

  # A bike can't be expected at a shop nobody named
  def shop_present_once_shipping_starts
    return unless fulfillment_shipped? && shipping_status?
    return if marketplace_partner_shop_id.present?

    errors.add(:marketplace_partner_shop, "is needed before a shipment starts")
  end
end
