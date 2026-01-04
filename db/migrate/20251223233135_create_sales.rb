class CreateSales < ActiveRecord::Migration[8.0]
  def change
    create_table :sales do |t|
      t.references :ownership
      t.references :item, polymorphic: true
      t.references :seller
      t.references :marketplace_message

      t.integer :amount_cents
      t.integer :currency_enum
      t.integer :sold_via
      t.string :sold_via_other
      t.datetime :sold_at
      t.string :new_owner_email
      t.boolean :remove_not_transfer

      t.timestamps
    end

    add_reference :marketplace_listings, :sale, index: true
    add_reference :ownerships, :sale, index: true
  end
end
