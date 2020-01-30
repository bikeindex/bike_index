class DropAlertImageFromStolenRecords < ActiveRecord::Migration[4.2]
  def change
    remove_column :stolen_records, :alert_image, :string
  end
end
