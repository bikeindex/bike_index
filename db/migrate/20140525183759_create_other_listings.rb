class CreateOtherListings < ActiveRecord::Migration
  def change
    create_table :other_listings do |t|
      t.integer :bike_id
      t.string :url
      t.string :listing_type

      t.timestamps
    end
  end
end
