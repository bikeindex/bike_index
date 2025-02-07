class RemoveDeliveryStatusStr < ActiveRecord::Migration[8.0]
  def change
    remove_column :notifications, :delivery_status_str, :string
  end
end
