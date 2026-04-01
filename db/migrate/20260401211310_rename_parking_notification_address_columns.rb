class RenameParkingNotificationAddressColumns < ActiveRecord::Migration[8.1]
  def change
    rename_column :parking_notifications, :zipcode, :postal_code
    rename_column :parking_notifications, :state_id, :region_record_id
    add_column :parking_notifications, :region_string, :string
  end
end
