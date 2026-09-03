class RemoveCurrencyMigration < ActiveRecord::Migration[8.0]
  def change
    remove_column :invoices, :currency, :string
    remove_column :organization_features, :currency, :string
    remove_column :payments, :currency, :string
    remove_column :stolen_bike_listings, :currency, :string
    remove_column :theft_alert_plans, :currency, :string
  end
end
