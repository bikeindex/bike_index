class ProcessHotSheetWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    30.minutes
  end

  def perform(org_id = nil)
    return enqueue_workers unless org_id.present?
    hot_sheet = HotSheet.for(org_id, Time.current)
    return hot_sheet if hot_sheet&.email_success?
    hot_sheet ||= HotSheet.create(organization_id: org_id)
    hot_sheet.fetch_stolen_records
    hot_sheet.fetch_recipients
    hot_sheet.deliver_email
  end

  def organizations
    Organization.with_enabled_feature_slugs("hot_sheet").left_joins(:hot_sheet_configuration)
      .where(hot_sheet_configurations: { is_enabled: true })
  end

  def enqueue_workers
    organizations.each do |organization|
      next unless organization.hot_sheet_configuration&.send_today_now?
      self.class.perform_async(organization.id)
    end
  end
end
