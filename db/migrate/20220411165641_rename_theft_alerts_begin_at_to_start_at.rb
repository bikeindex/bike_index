class RenameTheftAlertsBeginAtToStartAt < ActiveRecord::Migration[6.1]
  def change
    rename_column :theft_alerts, :begin_at, :start_at
    add_column :theft_alerts, :admin, :boolean, default: false
    add_column :theft_alerts, :ad_radius_miles, :integer
  end
end
