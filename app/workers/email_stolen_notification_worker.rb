class EmailStolenNotificationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'email'
  sidekiq_options backtrace: true

  def perform(stolen_notification_id)
    @stolen_notification = StolenNotification.find(stolen_notification_id)
    CustomerMailer.stolen_notification_email(@stolen_notification).deliver
  end

end