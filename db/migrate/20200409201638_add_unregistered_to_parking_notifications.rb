class AddUnregisteredToParkingNotifications < ActiveRecord::Migration[5.2]
  def change
    add_column :parking_notifications, :unregistered_bike, :boolean, default: false
  end
end
