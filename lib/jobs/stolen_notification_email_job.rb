class StolenNotificationEmailJob
  @queue = "email"

  def self.perform(stolen_notification_id)
    @stolen_notification = StolenNotification.find(stolen_notification_id)
    CustomerMailer.stolen_notification_email(@stolen_notification).deliver
  end

end