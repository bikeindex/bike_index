class RemoveDeliveryStatusStr < ActiveRecord::Migration[8.0]
  def change
    remove_column :notifications, :delivery_status_str, :string
    add_column :user_emails, :last_email_errored, :boolean, default: false
  end
end
