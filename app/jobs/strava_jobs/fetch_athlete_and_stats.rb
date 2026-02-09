module StravaJobs
  class FetchAthleteAndStats < ApplicationJob
    sidekiq_options queue: "low_priority", retry: 3

    def perform(strava_integration_id)
      return if skip_job?

      strava_integration = StravaIntegration.find_by(id: strava_integration_id)
      return unless strava_integration

      athlete_response = execute_request(strava_integration, :fetch_athlete, "athlete") {
        Integrations::Strava.fetch_athlete(strava_integration)
      }
      return unless athlete_response.success?
      athlete = athlete_response.body

      stats_response = execute_request(strava_integration, :fetch_athlete_stats, "athletes/#{athlete["id"]}/stats") {
        Integrations::Strava.fetch_athlete_stats(strava_integration, athlete["id"].to_s)
      }
      stats = stats_response.success? ? stats_response.body : nil

      strava_integration.update_from_athlete_and_stats(athlete, stats)
      strava_integration.update(status: :syncing)

      StravaRequest.create!(user_id: strava_integration.user_id, strava_integration_id: strava_integration.id,
        request_type: :list_activities, endpoint: "athlete/activities",
        parameters: {per_page: RequestRunner::ACTIVITIES_PER_PAGE})
    end

    private

    def execute_request(strava_integration, request_type, endpoint)
      request = StravaRequest.create!(
        user_id: strava_integration.user_id,
        strava_integration_id: strava_integration.id,
        request_type:, endpoint:, requested_at: Time.current
      )
      response = yield
      request.update!(
        response_status: response.success? ? :success : :error,
        rate_limit: RequestRunner.parse_rate_limit(response.headers)
      )
      response
    end
  end
end
