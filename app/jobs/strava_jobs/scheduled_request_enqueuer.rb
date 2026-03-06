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
        rate_limit = StravaRequest.estimated_current_rate_limit
        min_headroom = 2 * BATCH_SIZE
        (rate_limit[:read_short_limit] - rate_limit[:read_short_usage]) >= min_headroom &&
          (rate_limit[:read_long_limit] - rate_limit[:read_long_usage]) >= min_headroom
      end
    end

    def perform(skip_perform_in = false)
      return unless self.class.rate_limit_allows_batch?

      StravaRequest.next_pending(BATCH_SIZE).pluck(:id).each do |strava_request_id|
        RequestRunner.perform_async(strava_request_id)
      end
      return if skip_perform_in

      self.class.perform_in(15, true)
      self.class.perform_in(30, true)
      self.class.perform_in(45, true)
    end
  end
end
