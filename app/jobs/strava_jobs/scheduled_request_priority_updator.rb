# frozen_string_literal: true

module StravaJobs
  class ScheduledRequestPriorityUpdator < ScheduledJob
    prepend ScheduledJobRecorder

    MAX_PRIORITY = 10_000_000_000

    sidekiq_options queue: "low_priority", retry: 1

    class << self
      def frequency
        50.minutes
      end

      def min_updated_priority
        (StravaRequest::PRIORITY_MAP.except(:fetch_activity).values.max + 1) *
          StravaRequest::PRIORITY_LEVEL_MULTIPLIER
      end

      def priority_multiplier(strava_integration_id)
        most_recent_proxy_at = StravaRequest.most_recent_proxy_at(strava_integration_id)
        return 1 unless most_recent_proxy_at

        elapsed = Time.current - most_recent_proxy_at
        if elapsed < 1.hour
          0.75
        elsif elapsed < 24.hours
          0.9
        elsif elapsed > 1.week
          4 # multiply by 4
        else
          1
        end
      end
    end

    def perform(strava_integration_id = nil)
      if strava_integration_id.present?
        update_priorities_for_integration(strava_integration_id)
      else
        StravaRequest.pending.fetch_activity
          .reorder(nil)
          .distinct
          .pluck(:strava_integration_id)
          .each { |integration_id| self.class.perform_async(integration_id) }
      end
    end

    private

    def update_priorities_for_integration(integration_id)
      multiplier = self.class.priority_multiplier(integration_id)
      return if multiplier == 1

      StravaRequest.pending.where(strava_integration_id: integration_id).find_each do |request|
        new_priority = (request.priority * multiplier).to_i.clamp(0, MAX_PRIORITY)
        next if new_priority < self.class.min_updated_priority

        request.update(priority: new_priority)
      end
    end
  end
end
