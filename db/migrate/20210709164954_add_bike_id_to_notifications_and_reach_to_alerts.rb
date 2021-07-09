class AddBikeIdToNotificationsAndReachToAlerts < ActiveRecord::Migration[5.2]
  def change
    add_reference :notifications, :bike, index: true
    add_column :theft_alerts, :reach, :integer
  end
end
