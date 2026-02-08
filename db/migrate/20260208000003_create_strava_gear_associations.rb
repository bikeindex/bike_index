class CreateStravaGearAssociations < ActiveRecord::Migration[8.0]
  def change
    create_table :strava_gear_associations do |t|
      t.references :strava_integration, null: false, foreign_key: true
      t.references :item, polymorphic: true, null: false
      t.string :strava_gear_id, null: false
      t.string :strava_gear_name
      t.timestamps
    end

    add_index :strava_gear_associations, [:item_type, :item_id], unique: true
    add_index :strava_gear_associations, [:strava_integration_id, :strava_gear_id]
  end
end
