class CreateMarketplaceOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :marketplace_orders do |t|
      t.references :marketplace_listing, null: false
      t.references :buyer
      t.references :seller
      t.references :sale

      t.integer :status
      t.integer :fulfillment_kind
      t.integer :currency_enum

      # amount_cents is what the buyer is charged; the rest are what it's made of
      t.integer :amount_cents
      t.integer :item_amount_cents
      t.integer :shipping_amount_cents
      t.integer :shop_fee_cents
      t.integer :platform_fee_cents

      t.string :stripe_payment_intent_id

      t.datetime :paid_at
      t.datetime :completed_at
      t.datetime :cancelled_at

      t.timestamps
    end
  end
end
