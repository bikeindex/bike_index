class CreateMarketplaceListings < ActiveRecord::Migration[8.0]
  def change
    create_table :marketplace_listings do |t|
      t.references :seller
      t.references :buyer
      t.references :item, polymorphic: true
      t.datetime :for_sale_at
      t.datetime :sold_at
      t.integer :price_cents
      t.boolean :willing_to_ship, default: false
      t.integer :status, default: 0

      t.timestamps
    end
  end
end
