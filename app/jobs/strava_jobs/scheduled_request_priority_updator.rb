# frozen_string_literal: true

module StravaJobs
  class ScheduledRequestPriorityUpdator < ScheduledJob
    prepend ScheduledJobRecorder

    sidekiq_options queue: "low_priority", retry: 1

    def self.frequency
      1.hour
    end

    def perform
      StravaRequest.unprocessed
        .distinct
        .pluck(:strava_integration_id)
        .each { |integration_id| update_priorities_for_integration(integration_id) }
    end

    private

    def update_priorities_for_integration(integration_id)
      multiplier = priority_multiplier(integration_id)
      return if multiplier == 1

      StravaRequest.unprocessed
        .where(strava_integration_id: integration_id)
        .find_each { |request| request.update(priority: (request.priority * multiplier).to_i) }
    end

    def priority_multiplier(integration_id)
      most_recent_proxy = StravaRequest.where(
        strava_integration_id: integration_id,
        request_type: :proxy
      ).where.not(requested_at: nil)
        .order(requested_at: :desc)
        .first

      return 1 unless most_recent_proxy

      elapsed = Time.current - most_recent_proxy.requested_at
      if elapsed < 1.hour
        0.25 # divide by 4
      elsif elapsed < 24.hours
        0.5 # divide by 2
      elsif elapsed > 1.week
        4 # multiply by 4
      else
        1
      end
    end
  end
end
