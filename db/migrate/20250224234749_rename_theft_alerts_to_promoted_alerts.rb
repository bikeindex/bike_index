class RenameTheftAlertsToPromotedAlerts < ActiveRecord::Migration[8.0]
  def change
    rename_table :theft_alerts, :promoted_alerts
    rename_table :theft_alert_plans, :promoted_alert_plans
  end
end
