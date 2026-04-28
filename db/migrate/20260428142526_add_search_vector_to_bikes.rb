class AddSearchVectorToBikes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      ALTER TABLE bikes ADD COLUMN IF NOT EXISTS search_vector tsvector
        GENERATED ALWAYS AS (
          setweight(to_tsvector('simple', coalesce(serial_number, '')), 'A') ||
          setweight(to_tsvector('simple', coalesce(cached_data, '')), 'B') ||
          setweight(to_tsvector('simple', coalesce(all_description, '')), 'C')
        ) STORED
    SQL

    add_index :bikes, :search_vector,
      using: :gin,
      name: :index_bikes_on_search_vector,
      algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :bikes, name: :index_bikes_on_search_vector,
      algorithm: :concurrently, if_exists: true

    execute "ALTER TABLE bikes DROP COLUMN IF EXISTS search_vector"
  end
end
