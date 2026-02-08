class CreateStravaActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :strava_activities do |t|
      t.references :strava_integration, null: false, foreign_key: false
      t.string :strava_id, null: false
      t.string :title
      t.text :description
      t.float :distance
      t.integer :year
      t.string :gear_id
      t.string :gear_name
      t.jsonb :photos, default: []
      t.float :start_latitude
      t.float :start_longitude
      t.string :location_city
      t.string :location_state
      t.string :location_country
      t.string :activity_type
      t.datetime :start_date

      t.timestamps
    end

    add_index :strava_activities, [:strava_integration_id, :strava_id], unique: true
  end
end
