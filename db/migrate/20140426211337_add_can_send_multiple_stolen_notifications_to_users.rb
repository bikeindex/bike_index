class AddCanSendMultipleStolenNotificationsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :can_send_many_stolenNotifications, :boolean, default: false, null: false
  end
end
