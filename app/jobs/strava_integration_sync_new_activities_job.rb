class StravaIntegrationSyncNewActivitiesJob < ScheduledJob
  prepend ScheduledJobRecorder

  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    6.hours
  end

  def perform(strava_integration_id = nil)
    return enqueue_workers unless strava_integration_id.present?

    strava_integration = StravaIntegration.find_by(id: strava_integration_id)
    return unless strava_integration&.synced?

    Integrations::Strava.sync_new_activities(strava_integration)
  end

  def enqueue_workers
    StravaIntegration.synced.pluck(:id).each do |id|
      self.class.perform_async(id)
    end
  end
end
