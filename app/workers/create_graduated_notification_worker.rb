# TODO: make scheduled rather than manual call
#  - inherit from ScheduledWorker
#  - update specs to include examples
class CreateGraduatedNotificationWorker < ApplicationWorker
  # prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    24.hours
  end

  def perform(org_id = nil, bike_id = nil)
    return enqueue_workers unless org_id.present?

    graduated_notification = GraduatedNotification.not_marked_remaining.where(organization_id: org_id, bike_id: bike_id).first
    return graduated_notification if graduated_notification.present?

    graduated_notification = GraduatedNotification.create(organization_id: org_id, bike_id: bike_id)
    graduated_notification.process_notification
  end

  def organizations
    Organization.where.not(graduated_notification_interval: nil)
                .with_enabled_feature_slugs("graduated_notifications")
  end

  def enqueue_workers
    organizations.each do |organization|
      GraduatedNotification.bike_ids_to_notify(organization).each do |bike_id|
        self.class.perform_async(organization.id, bike_id)
      end
    end
  end
end
