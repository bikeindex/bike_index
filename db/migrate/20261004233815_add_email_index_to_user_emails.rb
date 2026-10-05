class AddEmailIndexToUserEmails < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :user_emails, :email, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :user_emails, :email, algorithm: :concurrently, if_exists: true
  end
end
