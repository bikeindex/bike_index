class ReplaceLowerIndexesWithRegularIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :users, name: "index_users_on_lower_email", algorithm: :concurrently
    remove_index :users, name: "index_users_on_lower_username", algorithm: :concurrently

    add_index :users, :email,
      name: "index_users_on_email",
      where: "deleted_at IS NULL",
      algorithm: :concurrently
  end
end
