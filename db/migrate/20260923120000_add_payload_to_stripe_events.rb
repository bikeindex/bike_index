class AddPayloadToStripeEvents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :stripe_events, :payload, :jsonb
    add_column :stripe_events, :stripe_event_id, :string
    # Set on Stripe Connect events, which arrive on behalf of a connected account
    add_column :stripe_events, :stripe_account_id, :string
    add_index :stripe_events, :stripe_id, algorithm: :concurrently
    add_index :stripe_events, :stripe_event_id, unique: true, algorithm: :concurrently
    add_index :stripe_events, :stripe_account_id, algorithm: :concurrently
  end
end
