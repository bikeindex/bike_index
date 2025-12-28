# == Schema Information
#
# Table name: sales
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  amount_cents           :integer
#  currency_enum          :integer
#  item_type              :string
#  new_owner_email        :string
#  remove_not_transfer    :boolean
#  sold_at                :datetime
#  sold_via               :integer
#  sold_via_other         :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  item_id                :bigint
#  marketplace_message_id :bigint
#  ownership_id           :bigint
#  seller_id              :bigint
#
# Indexes
#
#  index_sales_on_item                    (item_type,item_id)
#  index_sales_on_marketplace_message_id  (marketplace_message_id)
#  index_sales_on_ownership_id            (ownership_id)
#  index_sales_on_seller_id               (seller_id)
#
class Sale < ApplicationRecord
  SOLD_VIA_ENUM = {
    bike_index_marketplace: 0,
    facebook: 1,
    craigslist: 2,
    kijiji: 3,
    ebay: 4,
    pros_closet: 5,
    friend: 6,
    other: 7
  }

  include Amountable
  include Currencyable

  enum :sold_via, SOLD_VIA_ENUM

  # TODO: create a bike_version and assign that to the item
  belongs_to :item, polymorphic: true
  belongs_to :seller, class_name: "User"
  belongs_to :ownership
  belongs_to :marketplace_message

  has_one :marketplace_listings
  has_one :new_ownership, class_name: "Ownership", foreign_key: :sale_id
  has_one :buyer, through: :new_ownership, class_name: "User", source: :user

  # validates_presence_of :item_id
  validates_presence_of :seller_id

  before_validation :set_calculated_attributes
  after_commit :enqueue_callback_job, on: :create

  private

  def set_calculated_attributes
    self.seller_id ||= ownership&.user_id
    self.sold_at ||= Time.current
    self.sold_via ||= :bike_index_marketplace if marketplace_message_id.present?
    self.item ||= ownership&.bike
    self.new_owner_email ||= email_from_marketplace_message
  end

  def email_from_marketplace_message
    return unless marketplace_message&.buyer_id.present?

    User.find_by_id(marketplace_message.buyer_id)&.email
  end

  def enqueue_callback_job
    CallbackJob::AfterSaleCreateJob.perform_async(id)
  end
end
