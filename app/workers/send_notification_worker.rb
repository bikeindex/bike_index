class SendNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(notification_id)
    notification = Notification.find_by_id(notification_id)
    return false unless notification.present?
    # If we already sent it, don't send again
    return false if notification.email_success?
    fail "we need to actually deliver email here"
    notification.update(delivery_status: "email_success") # I'm not sure how to make this more representative
  end
end
