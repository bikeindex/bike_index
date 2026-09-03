class CreateStravaIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :strava_integrations do |t|
      t.references :user, null: false, foreign_key: false, index: false
      t.text :access_token, null: false
      t.text :refresh_token, null: false
      t.datetime :token_expires_at
      t.string :strava_permissions
      t.string :athlete_id
      t.integer :athlete_activity_count
      t.integer :activities_downloaded_count, default: 0, null: false
      t.integer :status, default: 0, null: false
      t.datetime :last_updated_activities_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :strava_integrations, :deleted_at
    add_index :strava_integrations, :user_id, unique: true, where: "deleted_at IS NULL"
  end
end
