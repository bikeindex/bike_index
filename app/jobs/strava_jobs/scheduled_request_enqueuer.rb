# frozen_string_literal: true

module StravaJobs
  class ScheduledRequestEnqueuer < ScheduledJob
    prepend ScheduledJobRecorder

    BATCH_SIZE = ENV.fetch("STRAVA_BULK_ENQUEUE_SIZE", 40).to_i
    ENQUEUER_FETCH_ACTIVITY_SHORT_HEADROOM = ENV.fetch("STRAVA_ENQUEUER_FETCH_ACTIVITY_SHORT_HEADROOM",
      Integrations::Strava::Client::FETCH_ACTIVITY_SHORT_HEADROOM * 2).to_i
    ENQUEUER_FETCH_ACTIVITY_LONG_HEADROOM = ENV.fetch("STRAVA_ENQUEUER_FETCH_ACTIVITY_LONG_HEADROOM",
      Integrations::Strava::Client::FETCH_ACTIVITY_LONG_HEADROOM * 2).to_i

    sidekiq_options queue: "low_priority"

    class << self
      def frequency
        59 # The scheduler runs every 60 seconds - run it every time
      end

      def rate_limit_allows_batch?
        !Integrations::Strava::Client.currently_rate_limited?(headroom: 2 * BATCH_SIZE)
      end

      def skip_enqueueing_fetch_activity_requests?
        return true if Integrations::Strava::Client.currently_rate_limited?(request_type: :fetch_activity)

        rate_limit = StravaRequest.estimated_current_rate_limit
        (rate_limit[:read_short_limit] - rate_limit[:read_short_usage]) < ENQUEUER_FETCH_ACTIVITY_SHORT_HEADROOM ||
          (rate_limit[:read_long_limit] - rate_limit[:read_long_usage]) < ENQUEUER_FETCH_ACTIVITY_LONG_HEADROOM
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
      return if skip_job?
      return unless self.class.rate_limit_allows_batch?
      return if enqueued_runner_count > 10

      skip_duplicate_requests # skip_duplicate_requests before enqueuing
      pending = StravaRequest.pending.priority_ordered
      pending = pending.where.not(request_type: :fetch_activity) if self.class.skip_enqueueing_fetch_activity_requests?
      batch = pending.limit(BATCH_SIZE)
      ensure_valid_tokens_for_batch(batch)
      batch.pluck(:id).each do |strava_request_id|
        RequestRunner.perform_async(strava_request_id)
      end
      return if skip_perform_in

      self.class.perform_in(15, true)
      self.class.perform_in(30, true)
      self.class.perform_in(45, true)
    end

    private

    def ensure_valid_tokens_for_batch(batch)
      integration_ids = batch.reorder(nil).distinct.pluck(:strava_integration_id)
      StravaIntegration.where(id: integration_ids).find_each do |strava_integration|
        Integrations::Strava::Client.ensure_valid_token!(strava_integration)
      end
    end

    def enqueued_runner_count
      Sidekiq::Queue.new(RequestRunner.sidekiq_options["queue"])
        .count { |job| job.klass == "StravaJobs::RequestRunner" }
    end

    def skip_duplicate_requests
      StravaRequest.where(id: self.class.duplicate_request_ids)
        .find_each { |r| r.update!(response_status: :skipped) }
    end
  end
end
