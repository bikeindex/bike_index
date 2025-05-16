class AddMessageIdToNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :notifications, :message_id, :string
  end
end
