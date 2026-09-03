class RemoveDeliveryStatusFromParkingNotifications < ActiveRecord::Migration[8.1]
  def change
    remove_column :parking_notifications, :delivery_status, :string
  end
end
