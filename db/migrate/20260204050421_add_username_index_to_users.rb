class AddUsernameIndexToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users, :username, where: "deleted_at IS NULL", algorithm: :concurrently
  end
end
