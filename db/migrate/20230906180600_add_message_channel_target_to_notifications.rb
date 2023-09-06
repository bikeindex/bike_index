class AddMessageChannelTargetToNotifications < ActiveRecord::Migration[6.1]
  def change
    add_column :notifications, :message_channel_target, :string
  end
end
