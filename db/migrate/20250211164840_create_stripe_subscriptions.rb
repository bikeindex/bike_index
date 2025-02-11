class CreateStripeSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_subscriptions do |t|
      t.references :membership, index: true
      t.references :stripe_price, index: true
      t.datetime :end_at
      t.datetime :start_at
      t.boolean :active, default: false

      t.timestamps
    end

    add_reference :payments, :stripe_subscription, index: true
  end
end
