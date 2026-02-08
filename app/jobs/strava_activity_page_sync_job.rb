class StravaActivityPageSyncJob < ApplicationJob
  RATE_LIMIT_DELAY = 10.seconds
  ACTIVITIES_PER_PAGE = 200

  sidekiq_options queue: "low_priority", retry: 3

  def perform(strava_integration_id, page, after_epoch = nil)
    si = StravaIntegration.find_by(id: strava_integration_id)
    return unless si

    activities = Integrations::Strava.list_activities(si, page:, per_page: ACTIVITIES_PER_PAGE, after: after_epoch)

    if activities.blank? || !activities.is_a?(Array)
      enqueue_detail_jobs_or_finish(si, after_epoch)
      return
    end

    activities.each { |summary| StravaActivity.create_or_update_from_summary(si, summary) }
    si.update(activities_downloaded_count: si.strava_activities.count)

    if activities.size >= ACTIVITIES_PER_PAGE
      self.class.perform_in(RATE_LIMIT_DELAY, si.id, page + 1, after_epoch)
    else
      enqueue_detail_jobs_or_finish(si, after_epoch)
    end
  end

  private

  def enqueue_detail_jobs_or_finish(si, after_epoch)
    activity_ids = cycling_activity_ids_needing_details(si, after_epoch)
    if activity_ids.empty?
      si.finish_sync!
      return
    end
    activity_ids.each_with_index do |id, i|
      last = (i == activity_ids.size - 1)
      StravaActivityDetailSyncJob.perform_in(RATE_LIMIT_DELAY * (i + 1), id, last)
    end
  end

  def cycling_activity_ids_needing_details(si, after_epoch)
    scope = si.strava_activities.cycling
    scope = scope.where("start_date > ?", Time.at(after_epoch)) if after_epoch
    scope.pluck(:id)
  end
end
