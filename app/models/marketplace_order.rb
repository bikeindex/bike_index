# == Schema Information
#
# Table name: marketplace_orders
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  amount_cents             :integer
#  cancelled_at             :datetime
#  completed_at             :datetime
#  currency_enum            :integer
#  fulfillment_kind         :integer
#  item_amount_cents        :integer
#  paid_at                  :datetime
#  platform_fee_cents       :integer
#  shipping_amount_cents    :integer
#  shop_fee_cents           :integer
#  status                   :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  buyer_id                 :bigint
#  marketplace_listing_id   :bigint           not null
#  sale_id                  :bigint
#  seller_id                :bigint
#  stripe_payment_intent_id :string
#
# Indexes
#
#  index_marketplace_orders_on_buyer_id                (buyer_id)
#  index_marketplace_orders_on_marketplace_listing_id  (marketplace_listing_id)
#  index_marketplace_orders_on_sale_id                 (sale_id)
#  index_marketplace_orders_on_seller_id               (seller_id)
#
class MarketplaceOrder < ApplicationRecord
  include Amountable
  include Currencyable

  # One sequence covers both ways of getting the bike to the buyer; local pickup skips the four
  # in the middle, which only mean anything once a shop is handling the bike.
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

  validates_presence_of :marketplace_listing_id, :status, :fulfillment_kind
  validate :buyer_is_not_seller
  validate :fulfillment_is_available
  validate :status_matches_fulfillment_kind

  before_validation :set_calculated_attributes

  scope :current, -> { where.not(status: ENDED_STATUSES) }

  class << self
    def statuses = STATUS_ENUM.keys.map(&:to_s)

    def fulfillment_kinds = FULFILLMENT_KIND_ENUM.keys.map(&:to_s)
  end

  def ended? = ENDED_STATUSES.include?(status&.to_sym)

  def paid? = paid_at.present?

  # What the buyer pays on top of the bike itself - shown separately so they can see what the
  # shop and the carrier are getting rather than one opaque total
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
    # Once charged, the total is a historical fact rather than a running sum - a later refund
    # adjusts the components without rewriting what the buyer actually paid. Still calculate it
    # when there's nothing there yet, or an order that arrives already paid never gets a total.
    self.amount_cents = component_amount_cents unless paid? && amount_cents.present?
  end

  def buyer_is_not_seller
    return if buyer_id.blank? || buyer_id != seller_id

    errors.add(:buyer_id, "can't buy your own listing")
  end

  def fulfillment_is_available
    return unless fulfillment_shipped?
    return if marketplace_listing&.shippable?

    errors.add(:fulfillment_kind, "isn't available for this listing")
  end

  def status_matches_fulfillment_kind
    return unless fulfillment_local_pickup?
    return unless SHIPPING_STATUSES.include?(status&.to_sym)

    errors.add(:status, "doesn't apply to a local pickup")
  end
end
