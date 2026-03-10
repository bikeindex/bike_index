class RemoveHideAddressFromParkingNotifications < ActiveRecord::Migration[8.1]
  def change
    remove_column :parking_notifications, :hide_address, :boolean, default: false
  end
end
