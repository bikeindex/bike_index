class AddDeliveryStatusToParkingNotifications < ActiveRecord::Migration[5.2]
  def change
    add_column :parking_notifications, :delivery_status, :string
  end
end
