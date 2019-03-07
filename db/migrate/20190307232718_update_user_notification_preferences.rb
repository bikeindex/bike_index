class UpdateUserNotificationPreferences < ActiveRecord::Migration
  def change
    rename_column :users, :is_emailable, :notification_newsletters
    add_column :users, :notification_unstolen, :boolean, default: true
  end
end
