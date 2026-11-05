class AddSerialTsvectorStatisticsToBikes < ActiveRecord::Migration[8.1]
  # The planner ignores the partial index's expression stats, so it guessed every serial
  # matched 0.5% of bikes and walked the ORDER BY index looking for them
  def up
    execute <<~SQL
      CREATE STATISTICS IF NOT EXISTS bikes_serial_normalized_tsvector
        ON (to_tsvector('simple', serial_normalized)) FROM bikes
    SQL
    execute "ANALYZE bikes"
  end

  def down
    execute "DROP STATISTICS IF EXISTS bikes_serial_normalized_tsvector"
  end
end
