class AddTrigramIndexToBikesSerialNormalizedNoSpace < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :bikes, :serial_normalized_no_space,
      using: :gin, opclass: :gin_trgm_ops,
      where: "example = false AND user_hidden = false AND likely_spam = false AND deleted_at IS NULL",
      name: :index_bikes_on_serial_normalized_no_space_trgm,
      algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :bikes, name: :index_bikes_on_serial_normalized_no_space_trgm,
      algorithm: :concurrently, if_exists: true
  end
end
