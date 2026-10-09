class AddEmailIndexToUserEmails < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # OwnerDuplicateFinder matches unconfirmed emails too, which the confirmed partial index skips
    add_index :user_emails, :email, algorithm: :concurrently
  end
end
