class AddReceiveStolenNotificationsToStolenRecord < ActiveRecord::Migration
  def change
    add_column :stolen_records, :receive_notifications, :boolean, default: true, null: true
  end
end
