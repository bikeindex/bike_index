class RenameImpoundRecordUpdatesResolvedAndAddParkingNotificationsRepeatNumber < ActiveRecord::Migration[5.2]
  def change
    rename_column :impound_record_updates, :resolved, :processed
    add_column :parking_notifications, :repeat_number, :integer
    add_column :parking_notifications, :not_last_notification, :boolean, default: false
  end
end
