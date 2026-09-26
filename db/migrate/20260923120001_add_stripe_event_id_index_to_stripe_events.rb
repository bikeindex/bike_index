class AddStripeEventIdIndexToStripeEvents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :stripe_events, :stripe_event_id, unique: true, algorithm: :concurrently
  end
end
