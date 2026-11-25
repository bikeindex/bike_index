class AddLookupIndexesToBikeStickers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :bike_stickers, :code_integer,
      algorithm: :concurrently, if_not_exists: true

    add_index :bike_stickers, :code,
      using: :gin, opclass: :gin_trgm_ops,
      name: :index_bike_stickers_on_code_trgm,
      algorithm: :concurrently, if_not_exists: true
  end
end
