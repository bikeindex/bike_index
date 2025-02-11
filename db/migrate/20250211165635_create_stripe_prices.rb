class CreateStripePrices < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_prices do |t|
      t.integer :membership_kind
      t.integer :interval
      t.string :stripe_id

      t.timestamps
    end
  end
end
