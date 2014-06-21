class AddSendDatesAndReceiverEmailToStolenNotifications < ActiveRecord::Migration
  def change
    add_column :stolen_notifications, :send_dates, :text
    add_column :stolen_notifications, :receiver_email, :string
  end
end
