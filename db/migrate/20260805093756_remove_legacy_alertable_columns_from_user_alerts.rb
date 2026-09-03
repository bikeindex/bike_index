class RemoveLegacyAlertableColumnsFromUserAlerts < ActiveRecord::Migration[8.1]
  def change
    remove_column :user_alerts, :theft_alert_id, :bigint
    remove_column :user_alerts, :user_phone_id, :bigint
  end
end
