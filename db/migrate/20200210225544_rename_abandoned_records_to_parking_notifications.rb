class RenameAbandonedRecordsToParkingNotifications < ActiveRecord::Migration[5.2]
  def change
    rename_table :abandoned_records, :parking_notifications
    rename_column :parking_notifications, :initial_abandoned_record_id , :initial_record_id
  end
end
