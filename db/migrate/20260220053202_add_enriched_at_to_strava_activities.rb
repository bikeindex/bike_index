class AddEnrichedAtToStravaActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :strava_activities, :enriched_at, :datetime
  end
end
