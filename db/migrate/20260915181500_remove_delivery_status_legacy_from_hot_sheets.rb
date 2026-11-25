class RemoveDeliveryStatusLegacyFromHotSheets < ActiveRecord::Migration[8.1]
  def change
    remove_column :hot_sheets, :delivery_status_legacy, :string
  end
end
