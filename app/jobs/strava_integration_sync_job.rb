class StravaIntegrationSyncJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: 3

  def perform(strava_integration_id)
    return if skip_job?

    strava_integration = StravaIntegration.find_by(id: strava_integration_id)
    return unless strava_integration

    connection = Integrations::StravaConnection.new(strava_integration)
    connection.fetch_athlete_and_update
    connection.sync_all_activities
  end
end
