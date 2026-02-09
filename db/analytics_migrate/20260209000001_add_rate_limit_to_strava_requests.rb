class AddRateLimitToStravaRequests < ActiveRecord::Migration[6.1]
  def change
    add_column :strava_requests, :rate_limit, :jsonb
  end
end
