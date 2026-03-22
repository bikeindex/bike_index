# frozen_string_literal: true

module StravaJobs
  class ScheduledRequestEnqueuer < ScheduledJob
    prepend ScheduledJobRecorder

    BATCH_SIZE = ENV.fetch("STRAVA_BULK_ENQUEUE_SIZE", 40).to_i

    sidekiq_options queue: "low_priority"

    class << self
      def frequency
        59 # The scheduler runs every 60 seconds - run it every time
      end

      def rate_limit_allows_batch?
        !Integrations::StravaClient.currently_rate_limited?(headroom: 2 * BATCH_SIZE)
      end
    end

    def perform(skip_perform_in = false)
      return unless self.class.rate_limit_allows_batch?

      StravaRequest.next_pending(BATCH_SIZE).pluck(:id).each do |strava_request_id|
        RequestRunner.perform_async(strava_request_id)
      end
      return if skip_perform_in

      skip_duplicate_requests
      self.class.perform_in(15, true)
      self.class.perform_in(30, true)
      self.class.perform_in(45, true)
    end

    private

    def skip_duplicate_requests
      pending = StravaRequest.next_pending(1000)
      seen_activities = Set.new
      seen_gears = Set.new

      pending.each do |request|
        key = duplicate_key(request)
        next if key.nil?

        seen = request.fetch_gear? ? seen_gears : seen_activities
        if seen.include?(key)
          request.update!(response_status: :skipped)
        else
          seen.add(key)
        end
      end
    end

    def duplicate_key(request)
      if request.fetch_activity?
        [request.strava_integration_id, request.parameters&.dig("strava_id")]
      elsif request.fetch_gear?
        [request.strava_integration_id, request.parameters&.dig("strava_gear_id")]
      end
    end
  end
end
