class AddCreatedByAddressToParkingNotifications < ActiveRecord::Migration[5.2]
  def change
    add_column :parking_notifications, :location_from_address, :boolean, default: false
  end
end
