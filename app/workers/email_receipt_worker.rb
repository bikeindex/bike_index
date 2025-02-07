class EmailReceiptWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(id)
    payment = Payment.find(id)
    notification = payment.notifications.receipt.first
    # If already delivered, skip out!
    return true if notification&.delivered?
    notification ||= Notification.create(kind: "receipt", notifiable: payment)
    CustomerMailer.invoice_email(payment).deliver_now
    notification.update(delivery_status_str: "email_success", message_channel: "email")

    if payment.donation?
      EmailDonationWorker.perform_in(1.2.hours + (rand(9..55) * 60), payment.id)
    end
  end
end
