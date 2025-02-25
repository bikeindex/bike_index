class RenameTheftAlertsToPromotedAlerts < ActiveRecord::Migration[8.0]
  def change
    rename_table :theft_alerts, :promoted_alerts
    rename_table :theft_alert_plans, :promoted_alert_plans
    rename_column :user_alerts, :theft_alert_id, :promoted_alert_id
    rename_column :promoted_alerts, :theft_alert_plan_id, :promoted_alert_plan_id
  end
end
