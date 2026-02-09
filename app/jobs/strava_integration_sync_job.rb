class StravaIntegrationSyncJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: 3

  def perform(strava_integration_id)
    return if skip_job?

    strava_integration = StravaIntegration.find_by(id: strava_integration_id)
    return unless strava_integration

    StravaRequest.create!(
      user_id: strava_integration.user_id,
      strava_integration_id: strava_integration.id,
      request_type: :fetch_athlete,
      endpoint: "athlete"
    )
    StravaRequestRunnerJob.perform_async
  end
end
