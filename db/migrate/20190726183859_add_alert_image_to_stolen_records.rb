class AddAlertImageToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :alert_image, :string
  end
end
