class CreateStripeEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_events do |t|
      t.references :stripe_subscription, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
