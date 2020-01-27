class AddAlertImageToStolenRecords < ActiveRecord::Migration[4.2]
  def change
    add_column :stolen_records, :alert_image, :string
  end
end
