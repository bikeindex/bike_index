class AddEmailIndexToUserEmails < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :user_emails, :email, name: :index_user_emails_on_email, algorithm: :concurrently, if_not_exists: true
  end
end
