class AddOwnerEmailIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # bikes.owner_email already has a gin trigram index, which answers `=` ~1000x
  # slower than a btree - it stays for matching_domain's `ILIKE '%domain'`, so
  # these are named to keep the rollback off it
  def change
    add_index :ownerships, :owner_email, name: :index_ownerships_on_owner_email,
      algorithm: :concurrently, if_not_exists: true
    add_index :bikes, :owner_email, name: :index_bikes_on_owner_email,
      algorithm: :concurrently, if_not_exists: true
  end
end
