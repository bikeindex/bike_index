class AddStravaDataToStravaIntegrations < ActiveRecord::Migration[8.1]
  def change
    add_column :strava_integrations, :strava_data, :jsonb
    rename_column :strava_gears, :strava_gear_name, :name
  end
end
