# == Schema Information
#
# Table name: marketplace_partner_shops
# Database name: primary
#
#  id               :bigint           not null, primary key
#  booked_by        :integer
#  boxing_fee_cents :integer
#  currency_enum    :integer
#  status           :integer
#  weekly_capacity  :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  location_id      :bigint
#  organization_id  :bigint           not null
#
# Indexes
#
#  index_marketplace_partner_shops_on_location_id      (location_id)
#  index_marketplace_partner_shops_on_organization_id  (organization_id) UNIQUE
#
class MarketplacePartnerShop < ApplicationRecord
  # A bike shop that boxes marketplace bikes for shipping, and takes a cut for doing it.
  #
  # Deliberately thin: the shop is already an Organization with kind bike_shop, its address a
  # Location, and who may act for it an OrganizationRole.

  include Currencyable

  FEATURE_SLUG = "marketplace_partner"

  STATUS_ENUM = {pending: 0, active: 1, paused: 2}.freeze
  # Per shop rather than global: a shop that already ships may prefer to buy the label itself
  BOOKED_BY_ENUM = {bike_index_account: 0, partner_shop_account: 1}.freeze

  enum :status, STATUS_ENUM
  enum :booked_by, BOOKED_BY_ENUM, prefix: :booked_by

  belongs_to :organization
  belongs_to :location

  has_many :marketplace_orders

  validates_presence_of :organization_id, :status
  validates_uniqueness_of :organization_id, if: :organization_id_changed?
  validate :organization_is_a_bike_shop
  validate :location_belongs_to_organization

  before_validation :set_calculated_attributes

  # The organization feature is the kill switch, so it belongs in the scope rather than only in
  # enabled? - otherwise a shop whose feature was revoked still comes back from near
  scope :accepting, lambda {
    active.where.not(location_id: nil).joins(:organization)
      .merge(Organization.with_enabled_feature_slugs(FEATURE_SLUG))
  }

  class << self
    def statuses = STATUS_ENUM.keys.map(&:to_s)

    # Shops that could take a drop-off near where the seller is. Coordinates only - handing
    # GeocodeHelper a string would put a blocking geocode request inside a finder.
    def near(latitude_longitude, distance_miles = GeocodeHelper::DEFAULT_MARKETPLACE_DISTANCE)
      return none unless latitude_longitude.is_a?(Array) && latitude_longitude.length == 2

      bounds = GeocodeHelper.bounding_box(latitude_longitude, distance_miles)
      return none if bounds.blank?

      accepting.joins(:location).merge(Location.within_bounding_box(bounds))
    end
  end

  # Matches Amountable#amount, which this can't include - that concern is hardwired to
  # amount_cents and the shop's money column is boxing_fee_cents
  def boxing_fee
    fee = boxing_fee_cents.to_i / 100.00
    (fee % 1 != 0) ? fee : fee.round
  end

  def boxing_fee=(value)
    self.boxing_fee_cents = MoneyFormatter.convert_to_cents(value)
  end

  def boxing_fee_formatted = MoneyFormatter.money_format(boxing_fee_cents, currency_name)

  # Status is ours to set, the feature is the organization's - either one turns the shop off
  def enabled?
    active? && organization&.enabled?(FEATURE_SLUG)
  end

  private

  def set_calculated_attributes
    self.status ||= :pending
    self.booked_by ||= :bike_index_account
    self.location_id ||= organization&.locations&.first&.id
  end

  def organization_is_a_bike_shop
    return if organization.blank? || organization.bike_shop?

    errors.add(:organization, "needs to be a bike shop")
  end

  def location_belongs_to_organization
    return if location.blank? || location.organization_id == organization_id

    errors.add(:location, "isn't one of that shop's locations")
  end
end
