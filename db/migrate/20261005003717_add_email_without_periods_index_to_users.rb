class AddEmailWithoutPeriodsIndexToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # EmailBan matches gmail-style duplicates on REPLACE(email, '.', '')
  def up
    add_index :users, "REPLACE(email, '.', '')",
      where: "deleted_at IS NULL",
      name: :index_users_on_email_without_periods,
      algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :users, name: :index_users_on_email_without_periods,
      algorithm: :concurrently, if_exists: true
  end
end
