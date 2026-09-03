class AddDeliveryStatusEnumToHotSheets < ActiveRecord::Migration[8.1]
  def change
    rename_column :hot_sheets, :delivery_status, :delivery_status_legacy
    add_column :hot_sheets, :delivery_status, :integer, default: 0
    add_column :hot_sheets, :delivery_error, :string
  end
end
