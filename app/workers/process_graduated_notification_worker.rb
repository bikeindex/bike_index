# TODO: make scheduled rather than manual call
#  - inherit from ScheduledWorker
#  - update specs to include examples
class ProcessGraduatedNotificationWorker < ApplicationWorker
  # prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    1.hour
  end

  def perform(graduated_notification_id = nil)
    return enqueue_workers unless graduated_notification_id.present?

    graduated_notification = GraduatedNotification.find(graduated_notification_id)
    return graduated_notification if graduated_notification.processed?

    graduated_notification.process_notification
  end

  def enqueue_workers
    GraduatedNotification.pending.primary_notifications.pluck(:id).each do |id|
      self.class.perform_async(id)
    end
  end
end
