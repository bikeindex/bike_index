class DropSendDatesBackup < ActiveRecord::Migration
  def up
    remove_column :stolen_notifications, :send_dates_backup
  end

  def down
    add_column :stolen_notifications, :send_dates_backup, :text
  end
end
