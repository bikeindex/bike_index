class AddUserIdAndIdIndexToOwnerships < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :ownerships, %i[user_id id], algorithm: :concurrently, if_not_exists: true
    remove_index :ownerships, :user_id, name: :index_ownerships_on_user_id, algorithm: :concurrently
  end
end
