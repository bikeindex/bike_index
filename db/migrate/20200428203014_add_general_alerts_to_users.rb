class AddGeneralAlertsToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :general_alerts, :jsonb, default: []
  end
end
