# frozen_string_literal: true

module StravaJobs
  class EnqueueEnrichActivities < ApplicationJob
    REDLOCK_PREFIX = "StravaEnrichLock-#{Rails.env.slice(0, 3)}"

    sidekiq_options queue: "low_priority", retry: 3

    def self.redlock_key(strava_integration_id)
      "#{REDLOCK_PREFIX}-#{strava_integration_id}"
    end

    def perform(strava_integration_id)
      strava_integration = StravaIntegration.find_by(id: strava_integration_id)
      return unless strava_integration

      lock_manager = Redlock::Client.new([Bikeindex::Application.config.redis_default_url])
      redlock = lock_manager.lock(self.class.redlock_key(strava_integration_id), 5.minutes.in_milliseconds.to_i)
      return unless redlock

      begin
        enqueue_enrich_activity_requests(strava_integration)
        enqueue_gear_requests(strava_integration)
        strava_integration.strava_gears.find_each(&:update_total_distance!)
      ensure
        lock_manager.unlock(redlock)
      end
    end

    private

    def enqueue_enrich_activity_requests(strava_integration)
      already_enqueued = StravaRequest.pending
        .where(strava_integration_id: strava_integration.id, request_type: :fetch_activity)
        .pluck(Arel.sql("parameters->>'strava_id'"))

      strava_integration.strava_activities.not_enriched.where.not(strava_id: already_enqueued).pluck(:strava_id)
        .each do |strava_id|
          StravaRequest.create!(user_id: strava_integration.user_id, strava_integration_id: strava_integration.id,
            request_type: :fetch_activity, parameters: {strava_id:})
        end
    end

    def enqueue_gear_requests(strava_integration)
      already_enqueued = StravaRequest.pending
        .where(strava_integration_id: strava_integration.id, request_type: :fetch_gear)
        .pluck(Arel.sql("parameters->>'strava_gear_id'"))

      strava_integration.gear_ids_to_request.each do |strava_gear_id|
        next if already_enqueued.include?(strava_gear_id)
        StravaRequest.create!(user_id: strava_integration.user_id, strava_integration_id: strava_integration.id,
          request_type: :fetch_gear, parameters: {strava_gear_id:})
      end
    end
  end
end
