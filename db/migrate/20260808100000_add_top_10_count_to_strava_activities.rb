class AddTop10CountToStravaActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :strava_activities, :top_10_count, :integer
  end
end
