class CreateStravaGear < ActiveRecord::Migration[8.0]
  def change
    create_table :strava_gears do |t|
      t.references :strava_integration, null: false, foreign_key: false
      t.references :item, polymorphic: true, null: true, index: false
      t.string :strava_gear_id, null: false
      t.string :strava_gear_name
      t.integer :gear_type
      t.integer :total_distance_kilometers
      t.jsonb :strava_data
      t.datetime :last_updated_from_strava_at
      t.timestamps
    end

    add_index :strava_gears, [:item_type, :item_id], unique: true, where: "item_id IS NOT NULL"
    add_index :strava_gears, [:strava_integration_id, :strava_gear_id], unique: true
  end
end
