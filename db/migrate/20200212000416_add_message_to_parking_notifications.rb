class AddMessageToParkingNotifications < ActiveRecord::Migration[5.2]
  def change
    add_column :parking_notifications, :message, :text
    rename_column :parking_notifications, :notes, :internal_notes
  end
end
