class AddMissingIndexesForSlowQueries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :normalized_serial_segments, :segment, algorithm: :concurrently
    add_index :b_params, :created_bike_id, algorithm: :concurrently
  end
end
