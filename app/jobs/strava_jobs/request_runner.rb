# frozen_string_literal: true

module StravaJobs
  class RequestRunner < ApplicationJob
    sidekiq_options queue: "droppable", retry: 1

    class << self
      def make_request_and_update(strava_integration, strava_request)
        if strava_request.request_type == "incoming_webhook"
          return handle_incoming_webhook(strava_request, strava_integration)
        end

        request_method = strava_request.update_activity? ? "PUT" : "GET"
        if Integrations::StravaClient.currently_rate_limited?(request_method)
          strava_request.update!(response_status: :binx_response_rate_limited, requested_at: Time.current)
          StravaRequest.create!(user_id: strava_request.user_id, strava_integration_id: strava_request.strava_integration_id,
            request_type: strava_request.request_type, proxy_request: strava_request.proxy_request,
            parameters: strava_request.parameters.except("error_response_status"))
          return
        end

        response = make_request(strava_integration, strava_request.request_type, strava_request.parameters)
        strava_request.update_from_response(response, re_enqueue_if_rate_limited_or_unavailable: true,
          raise_on_error: true)

        if strava_request&.success?
          handle_response(strava_request, strava_integration, response&.body)
        end
        response&.body
      end

      private

      def make_request(strava_integration, strava_request_type, parameters)
        case strava_request_type
        when "list_activities"
          Integrations::StravaClient.list_activities(strava_integration, **parameters.symbolize_keys)
        when "fetch_activity"
          Integrations::StravaClient.fetch_activity(strava_integration, parameters["strava_id"])
        when "fetch_athlete"
          Integrations::StravaClient.fetch_athlete(strava_integration)
        when "fetch_gear"
          Integrations::StravaClient.fetch_gear(strava_integration, parameters["strava_gear_id"])
        else
          raise "Unknown Request type"
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
          StravaActivity.create_or_update_from_strava_response(strava_integration, response)
        elsif strava_request.fetch_athlete?
          strava_integration.update_from_athlete_and_stats(response)
        elsif strava_request.fetch_gear?
          StravaGear.update_from_strava(strava_integration, response)
        end
        strava_integration.update_sync_status
      end

      def handle_incoming_webhook(strava_request, strava_integration)
        strava_params = strava_request.parameters
        if strava_params["object_type"] == "activity"
          if strava_params["aspect_type"] == "delete"
            strava_integration.strava_activities.find_by(strava_id: strava_params["object_id"].to_s)&.destroy
          else
            strava_activity = StravaActivity.create_or_update_from_strava_response(strava_integration,
              {"id" => strava_params["object_id"].to_s}.merge(strava_params["updates"] || {}))
            strava_activity.update_from_strava!
          end
        elsif strava_params["object_type"] == "athlete"
          if strava_params.dig("updates", "authorized") == "false"
            strava_integration.destroy
          else
            StravaRequest.create!(user_id: strava_integration.user_id, strava_integration_id: strava_integration.id,
              request_type: :fetch_athlete)
          end
        end
        strava_request.update!(response_status: :success)

        strava_params
      end
    end

    # keyword args are just for calling inline
    def perform(strava_request_id, strava_request: nil, no_skip: false)
      strava_request ||= StravaRequest.find_by(id: strava_request_id)
      return if strava_request.blank? || strava_request&.requested_at.present?

      strava_integration = StravaIntegration.find_by(id: strava_request.strava_integration_id)
      if strava_integration.blank?
        return mark_requests_deleted(strava_request)
      elsif strava_request.skip_request? && !no_skip
        return mark_sibling_requests_skipped(strava_request)
      end

      self.class.make_request_and_update(strava_integration, strava_request)
    end

    private

    def mark_sibling_requests_skipped(strava_request)
      strava_request.update(response_status: :skipped)
      StravaRequest.pending
        .where(strava_integration_id: strava_request.strava_integration_id, request_type: :fetch_activity)
        .where("parameters->>'strava_id' = ?", strava_request.parameters["strava_id"])
        .where.not(id: strava_request.id)
        .find_each { |sibling_request| sibling_request.update(response_status: :skipped) }
    end

    def mark_requests_deleted(strava_request)
      strava_request.update(response_status: :integration_deleted)
      StravaRequest.pending.where(strava_integration_id: strava_request.strava_integration_id)
        .find_each { strava_request.update(response_status: :integration_deleted) }
    end
  end
end
