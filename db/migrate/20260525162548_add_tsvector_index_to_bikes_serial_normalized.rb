class AddTsvectorIndexToBikesSerialNormalized < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_bikes_on_serial_normalized_tsvector
      ON bikes USING gin (to_tsvector('simple', serial_normalized))
      WHERE example = false AND user_hidden = false AND likely_spam = false AND deleted_at IS NULL
    SQL
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_bikes_on_serial_normalized_tsvector"
  end
end
