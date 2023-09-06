class MigrateMessageChannelTargetWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    4.minutes
  end

  def self.potential_notifications
    Notification.where.not(delivery_status: nil).where(message_channel_target: nil)
  end

  def perform(notification_id = nil)
    return enqueue_workers if notification_id.nil?
    notification = Notification.find_by_id(notification_id)
    if notification.message_channel_target.blank?
      target = notification.send(:calculated_message_channel_target)
      notification.update_column(:message_channel_target, target) if target.present?
    end
  end

  def enqueue_workers
    self.class.potential_notifications.limit(1_000)
      .pluck(:id).each { |i| MigrateMessageChannelTargetWorker.perform_async(i) }
  end
end
