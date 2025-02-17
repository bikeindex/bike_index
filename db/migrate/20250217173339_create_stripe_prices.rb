class CreateStripePrices < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_prices do |t|
      t.integer :membership_kind
      t.integer :interval
      t.string :stripe_id
      t.integer :currency_enum
      t.integer :amount_cents
      t.boolean :live, default: false
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
