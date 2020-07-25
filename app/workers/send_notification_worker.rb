class SendNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(notification_id)
    notification = Notification.find_by_id(notification_id)
    return false unless notification.present?
    # If we already sent it, don't send again
    return false if notification.email_success?
    return false unless deliver_email(notification)
    notification.update(delivery_status: "email_success") # I'm not sure how to make this more representative
  end

  def deliver_email(notification)
    if notification.view_appointment?
      AppointmentMailer.view_appointment(notification.appointment).deliver_now
    else
      false
    end
  end
end
