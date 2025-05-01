class CreateMarketplaceListings < ActiveRecord::Migration[8.0]
  def change
    create_table :marketplace_listings do |t|
      t.references :seller
      t.references :buyer
      t.references :item, polymorphic: true
      t.references :address_record

      t.float :latitude
      t.float :longitude

      t.datetime :published_at
      t.datetime :end_at

      t.integer :currency_enum
      t.integer :amount_cents

      t.integer :status
      t.integer :condition

      t.timestamps
    end
  end
end
