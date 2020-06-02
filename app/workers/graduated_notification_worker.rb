class GraduatedNotificationWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    24.hours
  end

  def self.organizations
    Organization.where.not(graduated_notification_interval: nil)
                .with_enabled_feature_slugs("graduated_notifications")
  end

  def perform(org_id = nil, bike_id = nil)
    return enqueue_workers unless org_id.present?
    organization = Organization.find(org_id)
    pos_kind = organization.calculated_pos_kind
    return true unless organization.pos_kind != pos_kind
    organization.update_attributes(pos_kind: pos_kind)
  end

  def enqueue_workers
    self.class.organizations.each do |organization|
      self.class.perform_async(id)
    end
  end
end
