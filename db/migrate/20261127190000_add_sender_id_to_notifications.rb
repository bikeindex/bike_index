class AddSenderIdToNotifications < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :notifications, :sender_id, :bigint, if_not_exists: true
    add_index :notifications, :sender_id, where: "sender_id IS NOT NULL", algorithm: :concurrently, if_not_exists: true
  end
end
