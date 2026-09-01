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
  # Deliberately thin: the shop is already an Organization with kind bike_shop, its address is
  # already a Location, and who may act for it is already OrganizationRole. This holds only what
  # organizations don't have - the fee, the capacity, and how the shipment gets booked.

  include Currencyable

  FEATURE_SLUG = "marketplace_partner"

  STATUS_ENUM = {pending: 0, active: 1, paused: 2}.freeze
  # Whether we buy the label or the shop does on their own BikeFlights account. Undecided until
  # they answer, so it's per shop rather than global - shops that already ship may prefer their own.
  BOOKED_BY_ENUM = {bike_index_account: 0, partner_shop_account: 1}.freeze

  enum :status, STATUS_ENUM
  enum :booked_by, BOOKED_BY_ENUM, prefix: :booked_by

  belongs_to :organization
  belongs_to :location

  has_many :marketplace_orders

  validates_presence_of :organization_id, :status
  validates_uniqueness_of :organization_id
  validate :organization_is_a_bike_shop
  validate :location_belongs_to_organization

  before_validation :set_calculated_attributes

  scope :accepting, -> { active.where.not(location_id: nil) }

  class << self
    def statuses = STATUS_ENUM.keys.map(&:to_s)

    # Shops that could take a drop-off near where the seller is
    def near(latitude_longitude, distance_miles = 50)
      bounds = GeocodeHelper.bounding_box(latitude_longitude, distance_miles)
      return none if bounds.blank?

      accepting.joins(:location).merge(Location.within_bounding_box(bounds))
    end
  end

  def boxing_fee = boxing_fee_cents.to_i / 100.0

  def boxing_fee=(value)
    self.boxing_fee_cents = MoneyFormatter.convert_to_cents(value)
  end

  # Being switched on in admin isn't enough - the organization has to have the feature too, so
  # turning it off there takes the shop out of rotation without editing this record
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
