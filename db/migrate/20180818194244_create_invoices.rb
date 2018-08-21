class CreateInvoices < ActiveRecord::Migration
  def change
    create_table :invoices do |t|
      t.references :organization, index: true
      t.references :renews_subscription
      t.datetime :subscription_start_at
      t.datetime :subscription_end_at
      t.integer :feature_cost_at_start

      t.timestamps null: false
    end
  end
end
