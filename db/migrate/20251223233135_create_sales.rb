class CreateSales < ActiveRecord::Migration[8.0]
  def change
    create_table :sales do |t|
      t.integer :amount_cents
      t.integer :currency_enum
      t.references :item, polymorphic: true
      t.references :seller
      t.integer :sold_via
      t.string :sold_via_other
      t.datetime :sold_at
      t.references :ownership
      t.string :new_owner_string

      t.timestamps
    end

    add_reference :marketplace_listings, :sale, index: true
  end
end
