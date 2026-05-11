# frozen_string_literal: true

module Admin
  module StravaRequestsRateLimitDetails
    class Component < ApplicationComponent
      def initialize(now: Time.current.utc)
        @now = now
        @rate_limit_json = StravaRequest.estimated_current_rate_limit.as_json
        @batch_size = StravaJobs::ScheduledRequestEnqueuer::BATCH_SIZE
        @headroom = Integrations::Strava::Client::RATE_LIMIT_HEADROOM
        @fetch_activity_short_headroom = Integrations::Strava::Client::FETCH_ACTIVITY_SHORT_HEADROOM
        @fetch_activity_long_headroom = Integrations::Strava::Client::FETCH_ACTIVITY_LONG_HEADROOM
        @enqueuer_fetch_activity_short_headroom = StravaJobs::ScheduledRequestEnqueuer::ENQUEUER_FETCH_ACTIVITY_SHORT_HEADROOM
        @enqueuer_fetch_activity_long_headroom = StravaJobs::ScheduledRequestEnqueuer::ENQUEUER_FETCH_ACTIVITY_LONG_HEADROOM
      end

      private

      def short_resets_in
        (15 - @now.min % 15).minutes - @now.sec.seconds
      end

      def short_resets_display
        if short_resets_in < 60
          helpers.pluralize(short_resets_in.to_i, "second")
        else
          helpers.pluralize((short_resets_in / 60).to_i, "min")
        end
      end

      def long_resets_at
        @now.tomorrow.beginning_of_day
      end
    end
  end
end
