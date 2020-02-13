class AddLocationFromAddressToParkingNotificationsAndRemoveRetrievedAt < ActiveRecord::Migration[5.2]
  def change
    add_column :parking_notifications, :location_from_address, :boolean, default: false
    remove_column :parking_notifications, :retrieved_at, :timestamp
  end
end
