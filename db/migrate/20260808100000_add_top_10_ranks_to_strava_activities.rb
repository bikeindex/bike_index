class AddTop10RanksToStravaActivities < ActiveRecord::Migration[8.0]
  def change
    add_column :strava_activities, :top_10_ranks, :integer, array: true
  end
end
