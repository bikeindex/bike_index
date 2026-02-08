class StravaIntegrationSyncJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: 3

  def perform(strava_integration_id)
    return if skip_job?

    si = StravaIntegration.find_by(id: strava_integration_id)
    return unless si

    athlete = Integrations::Strava.fetch_athlete(si)
    return unless athlete
    stats = Integrations::Strava.fetch_athlete_stats(si, athlete["id"])
    si.update_from_athlete_and_stats(athlete, stats)
    si.update(status: :syncing)

    StravaActivityPageSyncJob.perform_in(StravaActivityPageSyncJob::RATE_LIMIT_DELAY, si.id, 1)
  end
end
