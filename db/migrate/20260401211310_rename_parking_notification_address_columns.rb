class RenameParkingNotificationAddressColumns < ActiveRecord::Migration[8.1]
  def change
    rename_column :parking_notifications, :zipcode, :postal_code if column_exists?(:parking_notifications, :zipcode)
    rename_column :parking_notifications, :state_id, :region_record_id if column_exists?(:parking_notifications, :state_id)
    add_column :parking_notifications, :region_string, :string unless column_exists?(:parking_notifications, :region_string)
  end
end
