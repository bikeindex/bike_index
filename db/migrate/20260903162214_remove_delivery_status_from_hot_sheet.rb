class RemoveDeliveryStatusFromHotSheet < ActiveRecord::Migration[8.1]
  def change
    remove_column :hot_sheets, :delivery_status, :string
    add_column :hot_sheets, :delivery_response, :jsonb
  end
end
