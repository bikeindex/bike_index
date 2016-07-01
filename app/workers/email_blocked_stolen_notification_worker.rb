class EmailBlockedStolenNotificationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(stolen_notification_id)
    @stolen_notification = StolenNotification.find(stolen_notification_id)
    AdminMailer.blocked_stolen_notification_email(@stolen_notification).deliver_now
  end

end