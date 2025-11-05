# == Schema Information
#
# Table name: item_sales
#
#  id               :bigint           not null, primary key
#  amount_cents     :integer
#  currency_enum    :integer
#  item_type        :string
#  new_owner_string :string
#  sold_at          :datetime
#  sold_via         :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  item_id          :bigint
#  ownership_id     :bigint
#  seller_id        :bigint
#
# Indexes
#
#  index_item_sales_on_item          (item_type,item_id)
#  index_item_sales_on_ownership_id  (ownership_id)
#  index_item_sales_on_seller_id     (seller_id)
#
class ItemSale < ApplicationRecord
  include Amountable
  include Currencyable

  belongs_to :item, polymorphic: true
  belongs_to :seller
  belongs_to :ownership
end
