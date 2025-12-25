# == Schema Information
#
# Table name: sales
# Database name: primary
#
#  id               :bigint           not null, primary key
#  amount_cents     :integer
#  currency_enum    :integer
#  item_type        :string
#  new_owner_string :string
#  sold_at          :datetime
#  sold_via         :integer
#  sold_via_other   :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  item_id          :bigint
#  ownership_id     :bigint
#  seller_id        :bigint
#
# Indexes
#
#  index_sales_on_item          (item_type,item_id)
#  index_sales_on_ownership_id  (ownership_id)
#  index_sales_on_seller_id     (seller_id)
#
class Sale < ApplicationRecord
  include Amountable
  include Currencyable

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

  belongs_to :item, polymorphic: true
  belongs_to :seller, class_name: "User"
  belongs_to :ownership

  has_many :marketplace_listings

  validates_presence_of :item_id
  validates_presence_of :seller_id
end
