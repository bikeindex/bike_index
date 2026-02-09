class AddDeletedAtToStravaIntegrations < ActiveRecord::Migration[8.1]
  def change
    add_column :strava_integrations, :deleted_at, :datetime
    add_index :strava_integrations, :deleted_at

    remove_index :strava_integrations, :user_id, unique: true
    add_index :strava_integrations, :user_id, unique: true, where: "deleted_at IS NULL"
  end
end
