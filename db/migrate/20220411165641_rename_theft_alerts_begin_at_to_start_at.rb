class RenameTheftAlertsBeginAtToStartAt < ActiveRecord::Migration[6.1]
  def change
    rename_column :theft_alerts, :begin_at, :start_at
  end
end
