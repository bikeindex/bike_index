class AddPartialIndexesToStravaRequests < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :strava_requests, :requested_at,
      order: {requested_at: :desc},
      where: "rate_limit IS NOT NULL",
      name: :index_strava_requests_on_requested_at_with_rate_limit,
      algorithm: :concurrently, if_not_exists: true

    add_index :strava_requests, [:strava_integration_id, :request_type],
      where: "response_status = 0",
      name: :index_strava_requests_pending_on_integration_id_request_type,
      algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :strava_requests,
      name: :index_strava_requests_pending_on_integration_id_request_type,
      algorithm: :concurrently, if_exists: true

    remove_index :strava_requests,
      name: :index_strava_requests_on_requested_at_with_rate_limit,
      algorithm: :concurrently, if_exists: true
  end
end
