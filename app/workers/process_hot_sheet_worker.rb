class ProcessHotSheetWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    30.minutes
  end

  def perform(org_id = nil)
    return enqueue_workers unless org_id.present?
  end

  def organizations
    Organization.with_enabled_feature_slugs("hot_sheet").left_joins(:hot_sheet_configuration)
      .where(hot_sheet_configurations: { is_enabled: true })
  end

  def enqueue_workers
    organizations.each do |organization|
      next unless organization.hot_sheet_configuration&.create_today_now?
      self.class.perform_async(organization.id)
    end
  end
end
