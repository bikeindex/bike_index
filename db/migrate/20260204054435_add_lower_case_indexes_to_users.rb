class AddLowerCaseIndexesToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users, "LOWER(email)",
      name: "index_users_on_lower_email",
      where: "deleted_at IS NULL",
      algorithm: :concurrently

    add_index :users, "LOWER(username)",
      name: "index_users_on_lower_username",
      where: "deleted_at IS NULL",
      algorithm: :concurrently
  end
end
