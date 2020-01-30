class AddCurrencyToAmountableTables < ActiveRecord::Migration[4.2]
  def change
    add_column :theft_alert_plans, :currency, :string, null: false, default: "USD"
    add_column :invoices, :currency, :string, null: false, default: "USD"
    add_column :paid_features, :currency, :string, null: false, default: "USD"
  end
end
