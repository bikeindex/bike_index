# frozen_string_literal: true

module StravaJobs
  class RequestRunner < ScheduledJob
    BATCH_SIZE = 10

    prepend ScheduledJobRecorder

    sidekiq_options queue: "low_priority", retry: false

    class << self
      def frequency
        16.seconds
      end

      def execute(strava_integration, strava_request_type, parameters)
        case strava_request_type
        when "list_activities"
          Integrations::StravaClient.list_activities(strava_integration, **parameters.symbolize_keys)
        when "fetch_activity"
          Integrations::StravaClient.fetch_activity(strava_integration, parameters["strava_id"])
        when "fetch_gear"
          Integrations::StravaClient.fetch_gear(strava_integration, parameters["strava_gear_id"])
        when "incoming_webhook"
          if parameters["object_type"] == "activity" && parameters["aspect_type"] != "delete"
            Integrations::StravaClient.fetch_activity(strava_integration, parameters["object_id"])
          end
        end
      end

      def handle_response(strava_request, strava_integration, response)
        if strava_request.incoming_webhook?
          handle_incoming_webhook(strava_request, strava_integration, response)
        elsif strava_request.list_activities?
          response.each { |summary| StravaActivity.create_or_update_from_strava_response(strava_integration, summary) }
          if strava_request.parameters["page"] == 1
            strava_integration.update(last_updated_activities_at: Time.current)
          end
          if strava_request.looks_like_last_page? && response.size == Integrations::StravaClient::ACTIVITIES_PER_PAGE
            StravaRequest.create!(user_id: strava_request.user_id, strava_integration_id: strava_integration.id,
              request_type: :list_activities, parameters: {page: strava_request.parameters["page"] + 1})
          end
        elsif strava_request.fetch_activity?
          strava_activity = strava_integration.strava_activities.find_by(strava_id: strava_request.parameters["strava_id"])
          strava_activity&.update_from_detail(response)
        elsif strava_request.fetch_gear?
          StravaGear.update_from_strava(strava_integration, response)
        end
        strava_integration.update_sync_status
      end

      def handle_incoming_webhook(strava_request, strava_integration, response)
        params = strava_request.parameters
        if params["object_type"] == "activity"
          if params["aspect_type"] == "delete"
            strava_integration.strava_activities.find_by(strava_id: params["object_id"].to_s)&.destroy
          else
            StravaActivity.create_or_update_from_strava_response(strava_integration, response)
          end
        elsif params["object_type"] == "athlete" && params.dig("updates", "authorized") == "false"
          strava_integration.destroy
        end
      end
    end

    def perform(strava_request_id = nil)
      return enqueue_next_request unless strava_request_id.present?

      strava_request = StravaRequest.find_by(id: strava_request_id)
      return if strava_request.blank? || strava_request&.requested_at.present?

      strava_integration = StravaIntegration.find_by(id: strava_request.strava_integration_id)
      if strava_integration.blank?
        return mark_requests_deleted(strava_request)
      elsif strava_request.skip_request?
        return strava_request.update(response_status: "skipped")
      end

      response = self.class.execute(strava_integration, strava_request.request_type, strava_request.parameters)
      strava_request.update_from_response(response, re_enqueue_if_rate_limited: true)
      return unless strava_request.success?

      self.class.handle_response(strava_request, strava_integration, response&.body)
      response&.body
    end

    private

    def enqueue_next_request
      return unless rate_limit_allows_batch?

      StravaRequest.next_pending(BATCH_SIZE).pluck(:id).each do |strava_request_id|
        self.class.perform_async(strava_request_id)
      end
    end

    def rate_limit_allows_batch?
      rate_limit = StravaRequest.estimated_current_rate_limit
      min_headroom = 2 * BATCH_SIZE
      (rate_limit["read_short_limit"].to_i - rate_limit["read_short_usage"].to_i) >= min_headroom &&
        (rate_limit["read_long_limit"].to_i - rate_limit["read_long_usage"].to_i) >= min_headroom
    end

    def mark_requests_deleted(strava_request)
      strava_request.update(response_status: :integration_deleted)
      StravaRequest.pending.where(strava_integration_id: strava_request.strava_integration_id)
        .each(&:integration_deleted!)
    end
  end
end
