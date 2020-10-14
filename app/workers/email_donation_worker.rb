class EmailDonationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(id)
    payment = Payment.find(id)
    notification_kind = calculated_notification_kind(payment)
    notification = payment.notifications.where(kind: notification_kind).first
    # If already delivered, skip out!
    return true if notification&.delivered?
    notification ||= Notification.create(kind: notification_kind, notifiable: payment)

    DonationMailer.donation_email(notification_kind, payment).deliver_now
    notification.update(delivery_status: "email_success", message_channel: "email")
  end

  def calculated_notification_kind(payment)
    "donation_standard"
  end
end
