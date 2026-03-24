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
        !Integrations::Strava::Client.currently_rate_limited?(headroom: 2 * BATCH_SIZE)
      end

      def skip_enqueueing_fetch_activity_requests?
        return true if Integrations::Strava::Client.fetch_activity_requests_rate_limited?

        rate_limit = StravaRequest.estimated_current_rate_limit
        (rate_limit[:read_long_limit] - rate_limit[:read_long_usage]) < Integrations::Strava::Client::FETCH_ACTIVITY_LONG_HEADROOM * 2
      end

      def duplicate_request_ids(limit: 5_000)
        pending = StravaRequest.pending.priority_ordered.limit(limit)

        duplicate_ids_for(pending.fetch_activity, "parameters->>'strava_id'") +
          duplicate_ids_for(pending.fetch_gear, "parameters->>'strava_gear_id'") +
          duplicate_ids_for(pending.list_activities, "parameters->>'page'")
      end

      private

      def duplicate_ids_for(scope, strava_parameters)
        grouped = scope.reorder(nil).group(:strava_integration_id, Arel.sql(strava_parameters))
          .having("COUNT(*) > 1")
          .pluck(:strava_integration_id, Arel.sql(strava_parameters))

        grouped.flat_map do |integration_id, key_value|
          scope.where(strava_integration_id: integration_id)
            .where("#{strava_parameters} = ?", key_value)
            .order(:priority).pluck(:id).drop(1)
        end
      end
    end

    def perform(skip_perform_in = false)
      return unless self.class.rate_limit_allows_batch?

      skip_duplicate_requests # skip_duplicate_requests before enqueuing
      skip_fetch_activity_requests # skip fetch_activity requests if rate limited
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

    def skip_fetch_activity_requests
      return unless self.class.skip_enqueueing_fetch_activity_requests?

      StravaRequest.pending.fetch_activity
        .find_each { |r| r.update!(response_status: :skipped) }
    end
  end
end
