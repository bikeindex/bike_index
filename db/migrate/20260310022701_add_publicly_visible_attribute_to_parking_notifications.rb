class AddPubliclyVisibleAttributeToParkingNotifications < ActiveRecord::Migration[7.2]
  def change
    add_column :parking_notifications, :publicly_visible_attribute, :integer
  end
end
