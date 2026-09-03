class AddTrigramIndexToOwnershipsOwnerEmail < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :ownerships, :owner_email,
      using: :gin, opclass: :gin_trgm_ops,
      name: :index_ownerships_on_owner_email_trgm,
      algorithm: :concurrently, if_not_exists: true
  end
end
