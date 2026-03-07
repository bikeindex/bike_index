class AddProxyRequestToStravaRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :strava_requests, :proxy_request, :boolean, default: false, null: false
  end
end
