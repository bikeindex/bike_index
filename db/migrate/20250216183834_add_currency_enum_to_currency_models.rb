class AddCurrencyEnumToCurrencyModels < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :currency_enum, :integer
    add_column :organization_features, :currency_enum, :integer
    add_column :payments, :currency_enum, :integer
    add_column :stolen_bike_listings, :currency_enum, :integer
    add_column :theft_alert_plans, :currency_enum, :integer
  end
end
