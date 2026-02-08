class StravaIntegrationSyncJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: 3

  def perform(strava_integration_id)
    return if skip_job?

    si = StravaIntegration.find_by(id: strava_integration_id)
    return unless si

    StravaRequest.create!(
      user_id: si.user_id,
      strava_integration_id: si.id,
      request_type: :fetch_athlete,
      endpoint: "athlete"
    )
    StravaRequestRunnerJob.perform_async
  end
end
