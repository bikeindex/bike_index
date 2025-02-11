class CreateStripeSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_subscriptions do |t|
      t.references :membership, foreign_key: true
      t.integer :kind
      t.datetime :end_at

      t.timestamps
    end
  end
end
