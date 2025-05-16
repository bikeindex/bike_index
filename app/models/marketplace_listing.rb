# == Schema Information
#
# Table name: marketplace_listings
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
#  seller_id         :bigint
#
# Indexes
#
#  index_marketplace_listings_on_address_record_id  (address_record_id)
#  index_marketplace_listings_on_buyer_id           (buyer_id)
#  index_marketplace_listings_on_item               (item_type,item_id)
#  index_marketplace_listings_on_seller_id          (seller_id)
#
class MarketplaceListing < ApplicationRecord
  STATUS_ENUM = {draft: 0, for_sale: 1, sold: 2, removed: 3}.freeze
  CONDITION_ENUM = {new_in_box: 0, excellent: 1, good: 2, poor: 3, salvage: 4}.freeze
  CURRENT_STATUSES = %i[draft for_sale]

  include AddressRecorded
  include Amountable
  include Currencyable

  enum :status, STATUS_ENUM
  enum :condition, CONDITION_ENUM

  belongs_to :seller, class_name: "User"
  belongs_to :buyer, class_name: "User"
  belongs_to :item, polymorphic: true
  belongs_to :address_record

  has_many :marketplace_messages

  validates_presence_of :item_id
  validates_presence_of :seller_id
  validates_presence_of :status

  before_validation :set_calculated_attributes

  scope :current, -> { where(status: CURRENT_STATUSES) }

  # validate that there isn't another current listing for an item
  # validate when marked for_sale that it has all the required attributes

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

    def seller_permitted_parameters
      [
        :condition, :amount_with_nil, :price_negotiable, :description,
        address_record_attributes: (AddressRecord.permitted_params + %i[user_account_address])
      ].freeze
    end

    def status_humanized(str)
      str&.to_s&.gsub("_", " ")
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

  # make this more sophisticated!
  def still_for_sale_at
    return nil unless for_sale?

    item&.updated_by_user_at
  end

  def publish!
    return false unless validate_publishable?

    update(published_at: Time.current, status: "for_sale")
    item&.update(is_for_sale: true) # Only relevant to bikes
    true
  end

  def valid_publishable?
    return false if id.blank? || item.blank? || !item.current? || item.primary_activity.blank?

    amount_cents.present? && condition.present? && address_record&.address_present?
  end

  def validate_publishable?
    if item.blank? || !item.current?
      # Ensure the item is still around and visible
      errors.add(:base, :item_not_visible, item_type: item_type_display)
    elsif item.primary_activity.blank?
      errors.add(:base, :primary_activity_required, item_type: item_type_display)
    end

    errors.add(:base, :price_required) if amount_cents.blank?
    errors.add(:base, :condition_required) if condition.blank?

    errors.add(:base, :address_required) unless address_record&.address_present?

    errors.none?
  end

  def bike_ownership
    return nil unless item_type == "Bike"

    item.ownerships.order(:created_at).claimed.where("claimed_at < ?", created_at).last
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

  def set_calculated_attributes
    self.seller_id ||= item.user&.id
    self.status ||= :draft
  end
end
