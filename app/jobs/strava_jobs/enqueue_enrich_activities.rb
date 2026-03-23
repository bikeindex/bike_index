# frozen_string_literal: true

module StravaJobs
  class EnqueueEnrichActivities < ApplicationJob
    sidekiq_options queue: "low_priority", retry: 3

    def perform(strava_integration_id)
      strava_integration = StravaIntegration.find_by(id: strava_integration_id)
      return unless strava_integration

      enqueue_enrich_activity_requests(strava_integration)
      enqueue_gear_requests(strava_integration)
      strava_integration.strava_gears.find_each(&:update_total_distance!)
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
