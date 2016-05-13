class AddSendDatesAndReceiverEmailToStolenNotifications < ActiveRecord::Migration
  def change
    add_column :stolenNotifications, :send_dates, :text
    add_column :stolenNotifications, :receiver_email, :string
  end
end
