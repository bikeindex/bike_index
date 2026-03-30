# frozen_string_literal: true

module StravaJobs
  class RequestRunner < ApplicationJob
    REDLOCK_PREFIX = "StravaRequestRunnerLock-#{Rails.env.slice(0, 3)}"

    sidekiq_options queue: "droppable", retry: 1

    class << self
      def redlock_key(strava_request_id)
        "#{REDLOCK_PREFIX}-#{strava_request_id}"
      end

      def new_lock_manager
        Redlock::Client.new([Bikeindex::Application.config.redis_default_url])
      end

      def locked?(strava_request_id)
        new_lock_manager.locked?(redlock_key(strava_request_id))
      end

      def make_request_and_update(strava_integration, strava_request)
        if strava_request.incoming_webhook?
          return handle_incoming_webhook(strava_request, strava_integration)
        end

        if Integrations::Strava::Client.currently_rate_limited?(strava_request.request_method, request_type: strava_request.request_type)
          strava_request.update_from_response(:binx_response_rate_limited,
            re_enqueue_if_rate_limited_or_unavailable: !strava_request.proxy_request?)
          return
        end

        response = make_request(strava_integration, strava_request)
        strava_request.update_from_response(response,
          re_enqueue_if_rate_limited_or_unavailable: !strava_request.proxy_request?,
          raise_on_error: !strava_request.proxy_request?)

        if strava_request.success? && !strava_request.proxy_request?
          handle_response(strava_request, strava_integration, response&.body)
        end
        response
      end

      private

      def make_request(strava_integration, strava_request)
        if strava_request.proxy_request?
          return Integrations::Strava::Client.proxy_request(strava_integration,
            strava_request.parameters["url"],
            method: strava_request.parameters["method"],
            body: strava_request.parameters["body"])
        end

        case strava_request.request_type
        when "list_activities"
          Integrations::Strava::Client.list_activities(strava_integration, **strava_request.parameters.symbolize_keys)
        when "fetch_activity"
          Integrations::Strava::Client.fetch_activity(strava_integration, strava_request.parameters["strava_id"])
        when "fetch_athlete"
          Integrations::Strava::Client.fetch_athlete(strava_integration)
        when "fetch_gear"
          Integrations::Strava::Client.fetch_gear(strava_integration, strava_request.parameters["strava_gear_id"])
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
          if strava_request.looks_like_last_page? && response.size == Integrations::Strava::Client::ACTIVITIES_PER_PAGE
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
        strava_integration.update(last_updated_activities_at: Time.current)

        strava_params
      end
    end

    # keyword args are just for calling inline
    def perform(strava_request_id, strava_request: nil, no_skip: false)
      strava_request ||= StravaRequest.find_by(id: strava_request_id)
      return if strava_request.blank? || !strava_request.pending?

      lock_manager = self.class.new_lock_manager
      redlock = lock_manager.lock(self.class.redlock_key(strava_request_id), 5.minutes.in_milliseconds.to_i)
      return unless redlock

      begin
        strava_integration = StravaIntegration.find_by(id: strava_request.strava_integration_id)
        if strava_integration.blank?
          return mark_requests_deleted(strava_request)
        elsif strava_request.skip_request? && !no_skip
          return mark_sibling_requests_skipped(strava_request)
        end

        self.class.make_request_and_update(strava_integration, strava_request)
      ensure
        lock_manager.unlock(redlock)
      end
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
