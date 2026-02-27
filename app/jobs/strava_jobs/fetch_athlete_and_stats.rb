# frozen_string_literal: true

module StravaJobs
  class FetchAthleteAndStats < ApplicationJob
    sidekiq_options queue: "low_priority", retry: 5

    def self.total_pages(activity_count)
      if (activity_count || 0).to_i > 0
        a_count = (activity_count.to_f / Integrations::StravaClient::ACTIVITIES_PER_PAGE).ceil
        a_count + (a_count / 4.0).round
      else
        2
      end
    end

    def perform(strava_integration_id)
      return if skip_job?

      strava_integration = StravaIntegration.find_by(id: strava_integration_id)
      return unless strava_integration

      athlete_response = execute_request(strava_integration, :fetch_athlete) {
        Integrations::StravaClient.fetch_athlete(strava_integration)
      }
      return unless athlete_response.success?
      athlete = athlete_response.body

      stats_response = execute_request(strava_integration, :fetch_athlete_stats) {
        Integrations::StravaClient.fetch_athlete_stats(strava_integration)
      }
      strava_integration.update_from_athlete_and_stats(athlete, stats_response.success? ? stats_response.body : nil)

      self.class.total_pages(strava_integration.athlete_activity_count).times do |i|
        StravaRequest.create!(user_id: strava_integration.user_id, strava_integration_id: strava_integration.id,
          request_type: :list_activities, parameters: {page: i + 1})
        StravaJobs::RequestRunner.perform_async
      end
    end

    private

    def execute_request(strava_integration, request_type)
      request = StravaRequest.create!(
        user_id: strava_integration.user_id,
        strava_integration_id: strava_integration.id,
        request_type:,
        requested_at: Time.current
      )
      response = yield
      request.update_from_response(response)
      response
    end
  end
end
