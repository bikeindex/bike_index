class CreateDuplicateBikeGroups < ActiveRecord::Migration
  def change
    create_table :duplicate_bike_groups do |t|
      t.boolean :ignore, default: false, null: false
      t.datetime :added_bike_at

      t.timestamps
    end
    add_column :normalized_serial_segments, :duplicate_bike_group_id, :integer
    add_index :normalized_serial_segments, :duplicate_bike_group_id
  end
end
