# frozen_string_literal: true

module StravaJobs
  class FetchAthleteAndStats < ApplicationJob
    sidekiq_options queue: "low_priority", retry: 3

    def self.total_pages(activity_count)
      if (activity_count || 0).to_i > 0
        a_count = (activity_count.to_f / Integrations::Strava::Client::ACTIVITIES_PER_PAGE).ceil
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
        Integrations::Strava::Client.fetch_athlete(strava_integration)
      }
      raise unless athlete_response.success?
      athlete = athlete_response.body

      stats_response = execute_request(strava_integration, :fetch_athlete_stats) {
        Integrations::Strava::Client.fetch_athlete_stats(strava_integration)
      }
      strava_integration.update_from_athlete_and_stats(athlete, stats_response.success? ? stats_response.body : nil)

      self.class.total_pages(strava_integration.athlete_activity_count).times do |i|
        strava_request = StravaRequest.create!(user_id: strava_integration.user_id, request_type: :list_activities,
          strava_integration_id: strava_integration.id, parameters: {page: i + 1})
        StravaJobs::RequestRunner.perform_async(strava_request.id)
      end
    end

    private

    def execute_request(strava_integration, request_type)
      strava_request = StravaRequest.create!(
        user_id: strava_integration.user_id,
        strava_integration_id: strava_integration.id,
        request_type:,
        requested_at: Time.current,
        response_status: :success # prevent RequestRunner from running this
      )
      response = yield
      strava_request.update_from_response(response, re_enqueue_if_rate_limited_or_unavailable: true,
        raise_on_error: true)
      response
    end
  end
end
