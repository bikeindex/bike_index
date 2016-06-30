class SwitchSendDatesToJson < ActiveRecord::Migration
  def up
    rename_column :stolen_notifications, :send_dates, :send_dates_backup
    add_column :stolen_notifications, :send_dates, :json
  end

  def down
    remove_column :stolen_notifications, :send_dates
    rename_column :stolen_notifications, :send_dates_backup, :send_dates
  end
end
