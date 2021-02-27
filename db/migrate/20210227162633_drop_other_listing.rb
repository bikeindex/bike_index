class DropOtherListing < ActiveRecord::Migration[5.2]
  def change
    # Never used, removing before adding stolen_bike_listing to prevent confusion
    drop_table :other_listings
  end
end
