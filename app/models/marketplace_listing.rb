class MarketplaceListing < ApplicationRecord
  belongs_to :seller
  belongs_to :buyer
  belongs_to :item, polymorphic: true
end
