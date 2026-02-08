class CreateStravaIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :strava_integrations do |t|
      t.references :user, null: false, foreign_key: true, index: {unique: true}
      t.text :access_token, null: false
      t.text :refresh_token, null: false
      t.datetime :token_expires_at
      t.string :athlete_id
      t.integer :athlete_activity_count
      t.jsonb :athlete_gear, default: []
      t.integer :activities_downloaded_count, default: 0, null: false
      t.integer :status, default: 0, null: false

      t.timestamps
    end
  end
end
