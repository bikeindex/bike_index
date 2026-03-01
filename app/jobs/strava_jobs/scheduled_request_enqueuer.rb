# frozen_string_literal: true

module StravaJobs
  class ScheduledRequestEnqueuer < ScheduledJob
    prepend ScheduledJobRecorder

    sidekiq_options queue: "low_priority", retry: 1

    def self.frequency
      1.hour
    end

    def perform
      StravaRequest.unprocessed
        .distinct
        .pluck(:strava_integration_id)
        .each { |integration_id| enqueue_for_integration(integration_id) }
    end

    private

    def enqueue_for_integration(integration_id)
      batch_size = calculate_batch_size(integration_id)
      StravaRequest.unprocessed
        .where(strava_integration_id: integration_id)
        .priority_ordered
        .limit(batch_size)
        .pluck(:id)
        .each { |id| StravaJobs::RequestRunner.perform_async(id) }
    end

    def calculate_batch_size(integration_id)
      base = Integrations::StravaClient::BULK_ENQUEUE_SIZE

      most_recent_proxy = StravaRequest.where(
        strava_integration_id: integration_id,
        request_type: :proxy
      ).where.not(requested_at: nil)
        .order(requested_at: :desc)
        .first

      return base unless most_recent_proxy

      elapsed = Time.current - most_recent_proxy.requested_at
      if elapsed < 1.hour
        base / 4
      elsif elapsed < 24.hours
        base / 2
      elsif elapsed > 1.week
        base * 4
      else
        base
      end
    end
  end
end
