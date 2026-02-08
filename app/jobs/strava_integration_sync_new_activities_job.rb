class StravaIntegrationSyncNewActivitiesJob < ScheduledJob
  prepend ScheduledJobRecorder

  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    6.hours
  end

  def perform(strava_integration_id = nil)
    return enqueue_workers unless strava_integration_id.present?

    si = StravaIntegration.find_by(id: strava_integration_id)
    return unless si&.synced?

    latest = si.strava_activities.order(start_date: :desc).first
    after_epoch = latest&.start_date&.to_i

    StravaRequest.create!(
      user_id: si.user_id,
      strava_integration_id: si.id,
      request_type: :list_activities,
      endpoint: "athlete/activities",
      parameters: {page: 1, per_page: 200, after: after_epoch}.compact
    )
    StravaRequestRunnerJob.perform_async
  end

  def enqueue_workers
    StravaIntegration.synced.pluck(:id).each do |id|
      self.class.perform_async(id)
    end
  end
end
