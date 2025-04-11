class CreateMarketplaceListings < ActiveRecord::Migration[8.0]
  def change
    create_table :marketplace_listings do |t|
      t.references :seller
      t.references :buyer
      t.references :item, polymorphic: true
      t.references :address_record

      t.datetime :for_sale_at
      t.datetime :sold_at
      t.integer :price_cents
      t.boolean :willing_to_ship, default: false
      t.integer :status, default: 0

      t.float :latitude
      t.float :longitude

      t.timestamps
    end
  end
end
