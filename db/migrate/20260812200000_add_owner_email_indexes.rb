class AddOwnerEmailIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # The trigram indexes serve `=` ~1000x slower than a btree, and stay for the
  # domain searches (`ILIKE '%example.com'`) - hence naming these, so the
  # rollback can tell the two apart
  def change
    add_index :ownerships, :owner_email, name: :index_ownerships_on_owner_email,
      algorithm: :concurrently, if_not_exists: true
    add_index :bikes, :owner_email, name: :index_bikes_on_owner_email,
      algorithm: :concurrently, if_not_exists: true
  end
end
