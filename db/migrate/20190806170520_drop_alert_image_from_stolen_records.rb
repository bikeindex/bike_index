class DropAlertImageFromStolenRecords < ActiveRecord::Migration
  def change
    remove_column :stolen_records, :alert_image, :string
  end
end
