class ProcessGraduatedNotificationWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    1.hour
  end

  def perform(graduated_notification_id = nil)
    return if ENV["BLOCK_GRADUATION_NOTIFICATIONS"].present? # Block process graduated notification worker temporarily
    return enqueue_workers unless graduated_notification_id.present?

    graduated_notification = GraduatedNotification.find(graduated_notification_id)
    return graduated_notification if graduated_notification.processed?

    graduated_notification.process_notification
  end

  def enqueue_workers
    GraduatedNotification.pending.primary_notification.pluck(:id).each do |id|
      self.class.perform_async(id)
    end
  end
end
