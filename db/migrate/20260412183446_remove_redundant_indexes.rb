class RemoveRedundantIndexes < ActiveRecord::Migration[8.1]
  def change
    remove_index :bike_organization_notes, :bike_id, name: :index_bike_organization_notes_on_bike_id
    remove_index :strava_activities, :strava_integration_id, name: :index_strava_activities_on_strava_integration_id
    remove_index :strava_gears, :strava_integration_id, name: :index_strava_gears_on_strava_integration_id
  end
end
