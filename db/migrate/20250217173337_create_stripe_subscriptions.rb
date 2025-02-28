class CreateStripeSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_subscriptions do |t|
      t.references :membership, index: true
      t.references :user, index: true
      t.string :stripe_price_stripe_id
      t.string :stripe_id
      t.datetime :end_at
      t.datetime :start_at
      t.string :stripe_status

      t.timestamps
    end

    add_index :stripe_subscriptions, :stripe_price_stripe_id
    add_reference :payments, :stripe_subscription, index: true
  end
end
