class AddNotifiableAndMessageChannelAndTwilioSidToNotifications < ActiveRecord::Migration[5.2]
  def change
    add_reference :notifications, :notifiable, polymorphic: true, index: true
    add_column :notifications, :message_channel, :integer, default: 0
    add_column :notifications, :twilio_sid, :text
  end
end
