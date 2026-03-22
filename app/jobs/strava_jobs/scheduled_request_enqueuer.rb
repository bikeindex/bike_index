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

      def duplicate_request_ids(limit: 5_000)
        fetch_activity = StravaRequest.request_types[:fetch_activity]
        fetch_gear = StravaRequest.request_types[:fetch_gear]
        pending = StravaRequest.response_statuses[:pending]

        StravaRequest.find_by_sql([<<~SQL.squish, {pending:, fetch_activity:, fetch_gear:}]).map(&:id)
          SELECT id FROM (
            SELECT id, ROW_NUMBER() OVER (
              PARTITION BY strava_integration_id,
                CASE request_type
                  WHEN :fetch_activity THEN parameters->>'strava_id'
                  WHEN :fetch_gear THEN parameters->>'strava_gear_id'
                END
              ORDER BY priority
            ) AS rn
            FROM strava_requests
            WHERE response_status = :pending
              AND request_type IN (:fetch_activity, :fetch_gear)
            ORDER BY priority
            LIMIT #{limit}
          ) ranked
          WHERE rn > 1
        SQL
      end
    end

    def perform(skip_perform_in = false)
      return unless self.class.rate_limit_allows_batch?

      # skip_duplicate_requests before enqueuing
      skip_duplicate_requests
      StravaRequest.next_pending(BATCH_SIZE).pluck(:id).each do |strava_request_id|
        RequestRunner.perform_async(strava_request_id)
      end
      return if skip_perform_in

      self.class.perform_in(15, true)
      self.class.perform_in(30, true)
      self.class.perform_in(45, true)
    end

    private

    def skip_duplicate_requests
      StravaRequest.where(id: self.class.duplicate_request_ids)
        .find_each { |r| r.update!(response_status: :skipped) }
    end
  end
end
