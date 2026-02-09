module StravaJobs
  class FetchAthleteAndStats < ApplicationJob
    sidekiq_options queue: "low_priority", retry: 3

    def perform(strava_integration_id)
      return if skip_job?

      strava_integration = StravaIntegration.find_by(id: strava_integration_id)
      return unless strava_integration

      athlete_response = Integrations::Strava.fetch_athlete(strava_integration)
      return unless athlete_response.success?
      athlete = athlete_response.body

      stats_response = Integrations::Strava.fetch_athlete_stats(strava_integration, athlete["id"].to_s)
      stats = stats_response.success? ? stats_response.body : nil

      strava_integration.update_from_athlete_and_stats(athlete, stats)
      strava_integration.update(status: :syncing)

      StravaRequest.create_follow_up(strava_integration, :list_activities, "athlete/activities",
        per_page: RequestRunner::ACTIVITIES_PER_PAGE)
    end
  end
end
