class UpdateStravaActivitiesAttributes < ActiveRecord::Migration[8.1]
  def change
    add_column :strava_activities, :average_speed, :float
    add_column :strava_activities, :suffer_score, :float
    add_column :strava_activities, :strava_data, :jsonb
    remove_column :strava_activities, :year, :integer
    remove_column :strava_activities, :muted, :boolean, default: false
    rename_column :strava_activities, :activity_timezone, :timezone
  end
end
