class ProcessParkingNotificationJob < ApplicationJob
  REDLOCK_PREFIX = "ProcessParkingNotificationLock-#{Rails.env.slice(0, 3)}"

  sidekiq_options queue: "notify"

  def self.redlock_key(parking_notification_id)
    "#{REDLOCK_PREFIX}-#{parking_notification_id}"
  end

  def self.new_lock_manager
    Redlock::Client.new([Bikeindex::Application.config.redis_default_url])
  end

  def self.locked_for?(parking_notification_id)
    new_lock_manager.locked?(redlock_key(parking_notification_id))
  end

  def lock_duration_ms
    1.minute.in_milliseconds.to_i
  end

  def perform(parking_notification_id)
    lock_manager = self.class.new_lock_manager
    redlock = lock_manager.lock(self.class.redlock_key(parking_notification_id), lock_duration_ms)
    return unless redlock

    begin
      run(parking_notification_id)
    ensure
      lock_manager.unlock(redlock)
    end
  end

  private

  def run(parking_notification_id)
    parking_notification = ParkingNotification.find(parking_notification_id)

    if parking_notification.impound_notification? && parking_notification.impound_record_id.blank?
      impound_record = ImpoundRecord.create!(bike_id: parking_notification.bike_id,
        user_id: parking_notification.user_id,
        organization_id: parking_notification.organization_id,
        skip_update: true)
      parking_notification.resolved_at ||= Time.current
      parking_notification.update(impound_record_id: impound_record.id)
      ProcessImpoundUpdatesJob.new.perform(impound_record.id)
    end

    # Update all of them!
    parking_notification.associated_notifications.each do |pn|
      pn.impound_record_id = impound_record.id if impound_record.present?
      pn.update(updated_at: Time.current, skip_update: true)
    end

    # If there are any notifications from the same period, resolve them - even if they aren't associated
    if parking_notification.reload.resolved?
      parking_notification.notifications_from_period.active.each do |notification|
        # Add a note about it though, to document it
        notes = [notification.internal_notes, "resolved by parking notification ##{parking_notification.id}"]
        notification.update(resolved_at: parking_notification.resolved_at,
          internal_notes: notes.join(", "))
      end
    end

    send_notification_if_should(parking_notification)
  end

  def send_notification_if_should(parking_notification)
    return if parking_notification.email_success? || !parking_notification.send_email?

    notification = parking_notification.notifications.first ||
      Notification.create(kind: "parking_notification", notifiable: parking_notification,
        user_id: parking_notification.bike&.user_id, message_channel_target: parking_notification.email,
        bike_id: parking_notification.bike_id)
    notification.track_email_delivery do
      OrganizedMailer.parking_notification(parking_notification).deliver_now
    end
  end
end
