class AddDeliveryStatusEnumToNotifications < ActiveRecord::Migration[8.0]
  def change
    rename_column :notifications, :delivery_status, :delivery_status_str
    add_column :notifications, :delivery_status, :integer
  end
end
