class AddNotificationToUserAlerts < ActiveRecord::Migration[5.2]
  def change
    add_reference :user_alerts, :notification, index: true
  end
end
