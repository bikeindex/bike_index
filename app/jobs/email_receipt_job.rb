class EmailReceiptJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 3

  def perform(id)
    payment = Payment.find(id)
    notification = payment.notifications.receipt.first
    notification ||= Notification.create(kind: "receipt", notifiable: payment)
    notification.track_email_delivery do
      CustomerMailer.invoice_email(payment).deliver_now
    end
    return unless payment.donation?

    EmailDonationJob.perform_in(1.2.hours + (rand(9..55) * 60), payment.id)
  end
end
