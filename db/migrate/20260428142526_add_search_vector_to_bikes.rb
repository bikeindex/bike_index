class AddSearchVectorToBikes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BACKFILL_BATCH_SIZE = 5_000

  def up
    unless column_exists?(:bikes, :search_vector)
      # Adds a nullable column with no default — no table rewrite in PG >= 11.
      add_column :bikes, :search_vector, :tsvector
    end

    # Trigger keeps search_vector in sync with subsequent inserts/updates.
    # Installed before the backfill so concurrent writes don't leave NULLs.
    execute <<~SQL
      CREATE OR REPLACE FUNCTION bikes_search_vector_update() RETURNS trigger AS $$
      BEGIN
        NEW.search_vector :=
          setweight(to_tsvector('simple', coalesce(NEW.serial_number, '')), 'A') ||
          setweight(to_tsvector('simple', coalesce(NEW.cached_data, '')), 'B') ||
          setweight(to_tsvector('simple', coalesce(NEW.all_description, '')), 'C');
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;

      DROP TRIGGER IF EXISTS bikes_search_vector_trigger ON bikes;
      CREATE TRIGGER bikes_search_vector_trigger
        BEFORE INSERT OR UPDATE OF serial_number, cached_data, all_description
        ON bikes
        FOR EACH ROW EXECUTE FUNCTION bikes_search_vector_update();
    SQL

    # Backfill in batches; each batch is its own transaction so we never hold a long lock.
    last_id = 0
    loop do
      result = connection.exec_query(<<~SQL)
        WITH batch AS (
          SELECT id FROM bikes
          WHERE id > #{last_id} AND search_vector IS NULL
          ORDER BY id
          LIMIT #{BACKFILL_BATCH_SIZE}
        )
        UPDATE bikes SET search_vector =
          setweight(to_tsvector('simple', coalesce(serial_number, '')), 'A') ||
          setweight(to_tsvector('simple', coalesce(cached_data, '')), 'B') ||
          setweight(to_tsvector('simple', coalesce(all_description, '')), 'C')
        FROM batch WHERE bikes.id = batch.id
        RETURNING bikes.id;
      SQL

      break if result.rows.empty?

      last_id = result.rows.last.first
    end

    add_index :bikes, :search_vector,
      using: :gin,
      name: :index_bikes_on_search_vector,
      algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :bikes, name: :index_bikes_on_search_vector,
      algorithm: :concurrently, if_exists: true

    execute <<~SQL
      DROP TRIGGER IF EXISTS bikes_search_vector_trigger ON bikes;
      DROP FUNCTION IF EXISTS bikes_search_vector_update();
    SQL

    remove_column :bikes, :search_vector if column_exists?(:bikes, :search_vector)
  end
end
