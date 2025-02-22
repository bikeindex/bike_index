class CreateStripeEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_events do |t|
      t.string :stripe_id
      t.string :name

      t.timestamps
    end
  end
end
