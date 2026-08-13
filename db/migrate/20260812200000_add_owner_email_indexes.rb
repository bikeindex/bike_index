class AddOwnerEmailIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :ownerships, :owner_email, algorithm: :concurrently, if_not_exists: true
  end
end
