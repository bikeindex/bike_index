class StravaActivityDetailSyncJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: 3

  def perform(strava_activity_id, mark_synced = false)
    activity = StravaActivity.find_by(id: strava_activity_id)
    return unless activity

    detail = Integrations::Strava.fetch_activity(activity.strava_integration, activity.strava_id)
    return unless detail

    activity.update_from_detail(detail)
    activity.strava_integration.finish_sync! if mark_synced
  end
end
