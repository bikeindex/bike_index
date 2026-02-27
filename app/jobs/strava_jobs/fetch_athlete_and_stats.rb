# frozen_string_literal: true

module StravaJobs
  class FetchAthleteAndStats < ApplicationJob
    sidekiq_options queue: "low_priority", retry: 5

    def perform(strava_integration_id)
      return if skip_job?

      strava_integration = StravaIntegration.find_by(id: strava_integration_id)
      return unless strava_integration

      athlete_response = execute_request(strava_integration, :fetch_athlete) {
        Integrations::StravaClient.fetch_athlete(strava_integration)
      }
      return unless athlete_response.success?

      stats_response = execute_request(strava_integration, :fetch_athlete_stats) {
        Integrations::StravaClient.fetch_athlete_stats(strava_integration)
      }
      strava_integration.update_from_athlete_and_stats(athlete_response.body, stats_response.success? ? stats_response.body : nil)

      fetch_all_list_pages(strava_integration)
    end

    private

    def fetch_all_list_pages(strava_integration)
      total_pages = calculate_total_pages(strava_integration)
      page = 1

      while page <= total_pages
        response = execute_request(strava_integration, :list_activities, parameters: {page:}) {
          Integrations::StravaClient.list_activities(strava_integration, page:)
        }

        unless response.success?
          enqueue_remaining_pages(strava_integration, page, total_pages) if response.status == 429
          return
        end

        StravaActivity.bulk_upsert_from_responses(strava_integration, response.body)
        strava_integration.update(last_updated_activities_at: Time.current) if page == 1

        if page == total_pages && response.body.size == Integrations::StravaClient::ACTIVITIES_PER_PAGE
          total_pages += 1
        end
        page += 1
      end

      strava_integration.update_sync_status(force_update: true)
    end

    def calculate_total_pages(strava_integration)
      count = strava_integration.athlete_activity_count.to_i
      (count > 0) ? (count.to_f / Integrations::StravaClient::ACTIVITIES_PER_PAGE).ceil : 1
    end

    def enqueue_remaining_pages(strava_integration, from_page, total_pages)
      now = Time.current
      records = (from_page..total_pages).map do |page|
        {user_id: strava_integration.user_id, strava_integration_id: strava_integration.id,
         request_type: StravaRequest::REQUEST_TYPE_ENUM[:list_activities],
         response_status: StravaRequest::RESPONSE_STATUS_ENUM[:pending],
         parameters: {page:}, created_at: now, updated_at: now}
      end
      StravaRequest.insert_all(records)
      StravaJobs::RequestRunner.perform_async
    end

    def execute_request(strava_integration, request_type, parameters: nil)
      request = StravaRequest.create!(
        user_id: strava_integration.user_id,
        strava_integration_id: strava_integration.id,
        request_type:,
        parameters:,
        requested_at: Time.current
      )
      response = yield
      request.update_from_response(response, raise_on_error: false)
      response
    end
  end
end
