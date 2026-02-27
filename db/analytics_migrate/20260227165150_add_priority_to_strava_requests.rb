class AddPriorityToStravaRequests < ActiveRecord::Migration[6.1]
  def change
    add_column :strava_requests, :priority, :integer, null: false, default: 0
  end
end
