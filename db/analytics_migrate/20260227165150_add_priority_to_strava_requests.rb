class AddPriorityToStravaRequests < ActiveRecord::Migration[6.1]
  def change
    add_column :strava_requests, :priority, :bigint, null: false, default: 0
  end
end
