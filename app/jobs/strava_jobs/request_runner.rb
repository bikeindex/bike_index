module StravaJobs
  class RequestRunner < ScheduledJob
    ACTIVITIES_PER_PAGE = 200

    prepend ScheduledJobRecorder

    sidekiq_options queue: "low_priority", retry: false

    class << self
      def frequency
        16.seconds
      end

      def execute(request, strava_integration)
        response = case request.request_type
        when "list_activities"
          params = request.parameters.symbolize_keys.slice(:per_page, :page, :after)
          Integrations::Strava.list_activities(strava_integration, **params)
        when "fetch_activity"
          Integrations::Strava.fetch_activity(strava_integration, request.parameters["strava_id"])
        end

        rate_limit = parse_rate_limit(response.headers)

        if response.success?
          request.update(response_status: :success, rate_limit:)
          response.body
        elsif response.status == 429
          request.update(response_status: :rate_limited, rate_limit:)
          StravaRequest.create!(user_id: strava_integration.user_id, strava_integration_id: strava_integration.id,
            request_type: request.request_type, endpoint: request.endpoint, parameters: request.parameters.symbolize_keys)
          nil
        elsif response.status == 401
          request.update(response_status: :token_refresh_failed, rate_limit:)
          nil
        else
          request.update(response_status: :error, rate_limit:)
          raise "Strava API error #{response.status}: #{response.body}"
        end
      end

      def handle_response(request, strava_integration, response)
        case request.request_type
        when "list_activities" then handle_list_activities(request, strava_integration, response)
        when "fetch_activity" then handle_fetch_activity(request, strava_integration, response)
        end
      end

      def parse_rate_limit(headers)
        limit = headers["X-RateLimit-Limit"]
        usage = headers["X-RateLimit-Usage"]
        read_limit = headers["X-ReadRateLimit-Limit"]
        read_usage = headers["X-ReadRateLimit-Usage"]
        return unless limit.present? || usage.present?
        short_limit, long_limit = limit&.split(",")&.map(&:to_i)
        short_usage, long_usage = usage&.split(",")&.map(&:to_i)
        read_short_limit, read_long_limit = read_limit&.split(",")&.map(&:to_i)
        read_short_usage, read_long_usage = read_usage&.split(",")&.map(&:to_i)
        {short_limit:, short_usage:, long_limit:, long_usage:,
         read_short_limit:, read_short_usage:, read_long_limit:, read_long_usage:}.compact
      end

      private

      def handle_list_activities(request, strava_integration, activities)
        return strava_integration.finish_sync! if !activities.is_a?(Array) || activities.blank?

        activities.each { |summary| StravaActivity.create_or_update_from_summary(strava_integration, summary) }
        strava_integration.update(activities_downloaded_count: strava_integration.strava_activities.count)

        if activities.size >= ACTIVITIES_PER_PAGE
          current_page = request.parameters["page"] || 1
          params = {per_page: ACTIVITIES_PER_PAGE, page: current_page + 1}
          params[:after] = request.parameters["after"] if request.parameters["after"]
          StravaRequest.create!(user_id: strava_integration.user_id, strava_integration_id: strava_integration.id,
            request_type: :list_activities, endpoint: "athlete/activities", parameters: params)
        else
          enqueue_detail_requests(request, strava_integration)
        end
      end

      def handle_fetch_activity(request, strava_integration, detail)
        activity = strava_integration.strava_activities.find_by(id: request.parameters["strava_activity_id"])
        return unless activity

        activity.update_from_detail(detail)

        remaining = StravaRequest.unprocessed.where(strava_integration_id: strava_integration.id, request_type: :fetch_activity)
        strava_integration.finish_sync! if remaining.none?
      end

      def enqueue_detail_requests(request, strava_integration)
        activity_ids = strava_integration.strava_activities.cycling.where(segment_locations: nil).pluck(:id, :strava_id)

        if activity_ids.empty?
          strava_integration.finish_sync!
          return
        end

        activity_ids.each do |id, strava_id|
          StravaRequest.create!(user_id: strava_integration.user_id, strava_integration_id: strava_integration.id,
            request_type: :fetch_activity, endpoint: "activities/#{strava_id}",
            parameters: {strava_id: strava_id.to_s, strava_activity_id: id})
        end
      end
    end

    def perform(strava_request_id = nil)
      return enqueue_next_request unless strava_request_id.present?

      request = StravaRequest.find_by(id: strava_request_id)
      return unless request
      return if request.requested_at.present?

      strava_integration = StravaIntegration.find_by(id: request.strava_integration_id)
      unless strava_integration
        request.update(requested_at: Time.current, response_status: :error)
        return
      end

      request.update(requested_at: Time.current)
      response = self.class.execute(request, strava_integration)
      self.class.handle_response(request, strava_integration, response) if response
    end

    private

    def enqueue_next_request
      request = StravaRequest.next_pending
      self.class.perform_async(request.id) if request
    end
  end
end
