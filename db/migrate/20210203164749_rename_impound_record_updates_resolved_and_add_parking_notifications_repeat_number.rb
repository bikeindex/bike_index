class RenameImpoundRecordUpdatesResolvedAndAddParkingNotificationsRepeatNumber < ActiveRecord::Migration[5.2]
  def change
    rename_column :impound_record_updates, :resolved, :processed
    add_column :parking_notifications, :repeat_number, :integer
  end
end
