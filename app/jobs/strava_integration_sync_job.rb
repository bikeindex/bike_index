class StravaIntegrationSyncJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: 3

  def perform(strava_integration_id)
    return if skip_job?

    strava_integration = StravaIntegration.find_by(id: strava_integration_id)
    return unless strava_integration

    Integrations::StravaConnection.fetch_athlete_and_update(strava_integration)
    Integrations::StravaConnection.sync_all_activities(strava_integration)
  end
end
