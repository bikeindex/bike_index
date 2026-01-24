# == Schema Information
#
# Table name: marketplace_listings
# Database name: primary
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer
#  condition         :integer
#  currency_enum     :integer
#  description       :text
#  end_at            :datetime
#  item_type         :string
#  latitude          :float
#  longitude         :float
#  price_negotiable  :boolean          default(FALSE)
#  published_at      :datetime
#  status            :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  address_record_id :bigint
#  buyer_id          :bigint
#  item_id           :bigint
#  sale_id           :bigint
#  seller_id         :bigint
#
# Indexes
#
#  index_marketplace_listings_on_address_record_id  (address_record_id)
#  index_marketplace_listings_on_buyer_id           (buyer_id)
#  index_marketplace_listings_on_item               (item_type,item_id)
#  index_marketplace_listings_on_sale_id            (sale_id)
#  index_marketplace_listings_on_seller_id          (seller_id)
#
class MarketplaceListing < ApplicationRecord
  STATUS_ENUM = {draft: 0, for_sale: 1, sold: 2, removed: 3}.freeze
  CONDITION_ENUM = {new_in_box: 0, excellent: 1, good: 2, poor: 3, salvage: 4}.freeze
  CURRENT_STATUSES = %i[draft for_sale].freeze
  ENDED_STATUSES = STATUS_ENUM.keys - CURRENT_STATUSES

  include AddressRecorded
  include AddressRecordedWithinBoundingBox
  include Amountable
  include Currencyable

  enum :status, STATUS_ENUM
  enum :condition, CONDITION_ENUM

  belongs_to :seller, class_name: "User"
  belongs_to :buyer, class_name: "User"
  belongs_to :item, polymorphic: true
  belongs_to :address_record
  belongs_to :sale

  has_many :marketplace_messages

  validates_presence_of :item_id
  validates_presence_of :seller_id
  validates_presence_of :status

  before_validation :set_calculated_attributes
  after_commit :update_bike_for_sale

  scope :current, -> { where(status: CURRENT_STATUSES) }
  scope :removed_or_sold, -> { where(status: %i[removed sold]) }

  # validate that there isn't another current listing for an item

  delegate :primary_activity, :primary_activity_id, :user, to: :item, allow_nil: true

  class << self
    # Only works for bikes currently...
    def find_or_build_current_for(item, condition: :good)
      item.marketplace_listings.current.first ||
        new(status: :draft, item:, seller: item.user, address_record: item_address_record(item), condition:)
    end

    def condition_humanized(str)
      return nil unless CONDITION_ENUM.key?(str&.to_sym)

      I18n.t(str, scope: %i[activerecord enums marketplace_listing condition])
    end

    def condition_description_humanized(str)
      return nil unless CONDITION_ENUM.key?(str&.to_sym)

      I18n.t(str, scope: %i[activerecord enums marketplace_listing condition_description])
    end

    def condition_with_description_humanized(str)
      [condition_humanized(str), condition_description_humanized(str)].join(" - ")
    end

    def status_humanized(str)
      str&.to_s&.tr("_", " ")
    end

    def search(items, price_min_amount: nil, price_max_amount: nil)
      return items if price_min_amount.blank? && price_max_amount.blank?

      min_cents = Amountable.to_cents(price_min_amount)
      max_cents = Amountable.to_cents(price_max_amount)

      query_hash = if min_cents.present?
        max_cents.present? ? {amount_cents: min_cents..max_cents} : {amount_cents: min_cents..}
      else
        {amount_cents: ..max_cents}
      end
      items.joins(:current_marketplace_listing).where(marketplace_listings: query_hash)
    end

    def for_user(user_or_id)
      user_id = user_or_id.is_a?(User) ? user_or_id.id : user_or_id
      where(seller_id: user_id).or(where(buyer_id: user_id))
    end

    private

    def item_address_record(item)
      item.user&.address_record ||
        AddressRecord.new(user: item.user, kind: :marketplace_listing)
    end
  end

  def status_humanized
    self.class.status_humanized(status)
  end

  def current?
    CURRENT_STATUSES.include?(status&.to_sym)
  end

  def item_type_display
    item&.type_titleize || "bike"
  end

  def condition_humanized
    self.class.condition_humanized(condition)
  end

  def primary_activity_id=(val)
    item&.update(primary_activity_id: val)
  end

  # make this more sophisticated!
  def still_for_sale_at
    return nil unless for_sale?

    item&.updated_by_user_at
  end

  def just_published?
    @updated_for_sale && status == "for_sale" || false
  end

  def just_failed_to_publish?
    @failed_to_publish && status == "draft" || false
  end

  def valid_publishable?
    return false if item.blank? || !item.current? || primary_activity.blank?
    return false if item.is_a?(Bike) && !item.status_with_owner?

    amount_cents.present? && condition.present? && address_record&.address_present?
  end

  # Validate here doesn't save, but it adds errors
  def validate_publishable!
    if item.blank? || !item.current?
      # Ensure the item is still around and visible
      errors.add(:base, :item_not_visible, item_type: item_type_display)
    elsif primary_activity.blank?
      errors.add(:base, :primary_activity_required, item_type: item_type_display)
    end
    if item.is_a?(Bike) && !item.status_with_owner?
      if item.status_stolen?
        errors.add(:base, :bike_is_stolen, item_type: item_type_display)
      else
        errors.add(:base, :not_with_owner, item_type: item_type_display)
      end
    end

    errors.add(:base, :price_required) if amount_cents.blank?
    errors.add(:base, :condition_required) if condition.blank?

    errors.add(:base, :address_required) unless address_record&.address_present?

    errors.none?
  end

  def bike_ownership
    return nil unless item_type == "Bike"

    item.ownerships.claimed_at(created_at)
  end

  def price_firm?
    !price_negotiable?
  end

  # TODO: consolidate the handling of this and MarketplaceMessage.can_see_messages?
  # ... someday, users should get to choose to hide their sold items
  def visible_by?(passed_user = nil)
    for_sale? || authorized?(passed_user)
  end

  def authorized?(passed_user = nil)
    return false if passed_user.blank?
    return true if passed_user.superuser?

    return true if passed_user.id == seller_id

    sold? && passed_user.id == buyer_id
  end

  private

  def update_bike_for_sale
    return unless @updated_for_sale && item_type == "Bike"

    # If updating an older marketplace_listing, make sure it doesn't update the bike
    if item&.current_marketplace_listing.blank? || item&.current_marketplace_listing&.id == id
      item.update(is_for_sale: for_sale?)
    end
  end

  def set_calculated_attributes
    self.seller_id ||= item.user&.id
    self.status ||= "draft"

    if status == "for_sale"
      if valid_publishable?
        self.published_at ||= Time.current
      else
        @failed_to_publish = true
        self.status = "draft"
      end
    end

    @updated_for_sale = status_changed?
    self.published_at = nil if status == "draft"
    self.end_at ||= Time.current unless current?

    if address_record&.latitude.present?
      self.latitude = address_record.latitude
      self.longitude = address_record.longitude
    end
  end
end
