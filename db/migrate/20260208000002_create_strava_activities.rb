class CreateStravaActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :strava_activities do |t|
      t.references :strava_integration, null: false, foreign_key: false
      t.string :strava_id, null: false
      t.string :title
      t.text :description
      t.float :distance_meters
      t.integer :moving_time_seconds
      t.float :total_elevation_gain_meters
      t.string :sport_type
      t.boolean :private, default: false
      t.boolean :muted, default: false
      t.integer :kudos_count
      t.integer :year
      t.string :gear_id
      t.jsonb :photos, default: []
      t.jsonb :segment_locations, default: {}
      t.string :activity_type
      t.datetime :start_date

      t.timestamps
    end

    add_index :strava_activities, [:strava_integration_id, :strava_id], unique: true
  end
end
