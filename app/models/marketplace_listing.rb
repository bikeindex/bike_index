# == Schema Information
#
# Table name: marketplace_listings
#
#  id                  :bigint           not null, primary key
#  amount_cents        :integer
#  condition           :integer
#  currency_enum       :integer
#  for_sale_at         :datetime
#  item_type           :string
#  latitude            :float
#  longitude           :float
#  sold_at             :datetime
#  status              :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  address_record_id   :bigint
#  buyer_id            :bigint
#  item_id             :bigint
#  primary_activity_id :bigint
#  seller_id           :bigint
#
# Indexes
#
#  index_marketplace_listings_on_address_record_id    (address_record_id)
#  index_marketplace_listings_on_buyer_id             (buyer_id)
#  index_marketplace_listings_on_item                 (item_type,item_id)
#  index_marketplace_listings_on_primary_activity_id  (primary_activity_id)
#  index_marketplace_listings_on_seller_id            (seller_id)
#
class MarketplaceListing < ApplicationRecord
  STATUS_ENUM = {draft: 0, for_sale: 1, sold: 2, removed: 3}.freeze
  CONDITION_ENUM = {new_in_box: 0, like_new: 1, excellent: 2, good: 3, fair: 4, salvage: 5}.freeze

  include Amountable
  include Currencyable

  enum :status, STATUS_ENUM
  enum :condition, CONDITION_ENUM

  belongs_to :seller, class_name: "User"
  belongs_to :buyer, class_name: "User"
  belongs_to :item, polymorphic: true
  belongs_to :address_record
  belongs_to :primary_activity
end
