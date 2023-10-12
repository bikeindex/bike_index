class AddSerialSegmentsMigratedToBikes < ActiveRecord::Migration[6.1]
  def change
    add_column :bikes, :serial_segments_migrated_at, :datetime
  end
end
