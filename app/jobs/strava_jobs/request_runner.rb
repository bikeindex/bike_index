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
        when "fetch_athlete"
          Integrations::Strava.fetch_athlete(strava_integration)
        when "fetch_athlete_stats"
          Integrations::Strava.fetch_athlete_stats(strava_integration, request.parameters["athlete_id"])
        when "list_activities"
          params = request.parameters.symbolize_keys.slice(:per_page, :before, :after)
          Integrations::Strava.list_activities(strava_integration, **params)
        when "fetch_activity"
          Integrations::Strava.fetch_activity(strava_integration, request.parameters["strava_id"])
        end

        if response.success?
          request.update(response_status: :success)
          response.body
        elsif response.status == 429
          request.update(response_status: :rate_limited)
          StravaRequest.create_follow_up(strava_integration, request.request_type, request.endpoint, **request.parameters.symbolize_keys)
          nil
        elsif response.status == 401
          request.update(response_status: :token_refresh_failed)
          nil
        else
          request.update(response_status: :error)
          raise "Strava API error #{response.status}: #{response.body}"
        end
      end

      def handle_response(request, strava_integration, response)
        case request.request_type
        when "fetch_athlete" then handle_fetch_athlete(strava_integration, response)
        when "fetch_athlete_stats" then handle_fetch_athlete_stats(request, strava_integration, response)
        when "list_activities" then handle_list_activities(request, strava_integration, response)
        when "fetch_activity" then handle_fetch_activity(request, strava_integration, response)
        end
      end

      private

      def handle_fetch_athlete(strava_integration, athlete)
        StravaRequest.create_follow_up(strava_integration, :fetch_athlete_stats,
          "athletes/#{athlete["id"]}/stats",
          athlete_id: athlete["id"].to_s, athlete_data: athlete.slice("id", "bikes", "shoes"))
      end

      def handle_fetch_athlete_stats(request, strava_integration, stats)
        athlete_data = request.parameters["athlete_data"] || {}
        athlete = {"id" => request.parameters["athlete_id"]}.merge(athlete_data)
        strava_integration.update_from_athlete_and_stats(athlete, stats)
        strava_integration.update(status: :syncing)

        params = {per_page: ACTIVITIES_PER_PAGE}
        params[:after] = request.parameters["after"] if request.parameters["after"]
        StravaRequest.create_follow_up(strava_integration, :list_activities, "athlete/activities", **params)
      end

      def handle_list_activities(request, strava_integration, activities)
        return strava_integration.finish_sync! if !activities.is_a?(Array) || activities.blank?

        activities.each { |summary| StravaActivity.create_or_update_from_summary(strava_integration, summary) }
        strava_integration.update(activities_downloaded_count: strava_integration.strava_activities.count)

        if activities.size >= ACTIVITIES_PER_PAGE
          oldest_start = activities.filter_map { |a| a["start_date"] }.min
          before_epoch = oldest_start ? Time.parse(oldest_start).to_i : nil
          params = {per_page: ACTIVITIES_PER_PAGE}
          params[:before] = before_epoch if before_epoch
          params[:after] = request.parameters["after"] if request.parameters["after"]
          StravaRequest.create_follow_up(strava_integration, :list_activities, "athlete/activities", **params)
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
        after_epoch = request.parameters["after"]
        scope = strava_integration.strava_activities.cycling
        scope = scope.where("start_date > ?", Time.at(after_epoch.to_i)) if after_epoch
        activity_ids = scope.pluck(:id, :strava_id)

        if activity_ids.empty?
          strava_integration.finish_sync!
          return
        end

        activity_ids.each do |id, strava_id|
          StravaRequest.create_follow_up(strava_integration, :fetch_activity, "activities/#{strava_id}",
            strava_id: strava_id.to_s, strava_activity_id: id)
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
