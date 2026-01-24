class AddBikeVersionIdToMarketplaceListings < ActiveRecord::Migration[8.0]
  def change
    add_reference :marketplace_listings, :bike_version, index: true
  end
end
