class AddReceiveStolenNotificationsToStolenRecord < ActiveRecord::Migration
  def change
    add_column :stolenRecords, :receive_notifications, :boolean, default: true, null: true
  end
end
