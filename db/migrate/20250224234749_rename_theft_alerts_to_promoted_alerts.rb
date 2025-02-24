class RenameTheftAlertsToPromotedAlerts < ActiveRecord::Migration[8.0]
  def change
    rename_table :theft_alerts, :promoted_alerts
  end
end
