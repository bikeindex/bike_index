class RemoveDefaultFromStravaRequestPriority < ActiveRecord::Migration[6.1]
  def change
    change_column_default :strava_requests, :priority, from: 0, to: nil
  end
end
