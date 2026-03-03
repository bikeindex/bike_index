# frozen_string_literal: true

module StravaJobs
  class ScheduledRequestEnqueuer < ScheduledJob
    BATCH_SIZE = ENV.fetch("STRAVA_BULK_ENQUEUE_SIZE", 40).to_i

    prepend ScheduledJobRecorder

    sidekiq_options queue: "low_priority"

    class << self
      def frequency
        59 # The scheduler runs every 60 seconds - run it every time
      end

      def rate_limit_allows_batch?
        rate_limit = StravaRequest.estimated_current_rate_limit
        min_headroom = 2 * BATCH_SIZE
        (rate_limit["read_short_limit"].to_i - rate_limit["read_short_usage"].to_i) >= min_headroom &&
          (rate_limit["read_long_limit"].to_i - rate_limit["read_long_usage"].to_i) >= min_headroom
      end
    end

    def perform
      return unless self.class.rate_limit_allows_batch?

      StravaRequest.next_pending(BATCH_SIZE).pluck(:id).each do |strava_request_id|
        RequestRunner.perform_async(strava_request_id)
      end

      self.class.perform_in(15)
      self.class.perform_in(30)
      self.class.perform_in(45)
    end
  end
end
