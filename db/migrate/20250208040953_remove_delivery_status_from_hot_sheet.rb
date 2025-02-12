class RemoveDeliveryStatusFromHotSheet < ActiveRecord::Migration[8.0]
  def change
    remove_column :hot_sheets, :delivery_status, :string
    add_column :hot_sheets, :delivery_error_message, :text
  end
end
