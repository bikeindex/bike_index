class EmailDonationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(id)
    payment = Payment.find(id)
    return unless payment.present? && payment.donation?
    notification_kind = calculated_notification_kind(payment)
    notification = payment.notifications.where(kind: notification_kind).first
    # If already delivered, skip out!
    return true if notification&.delivered?
    notification ||= Notification.create(kind: notification_kind, notifiable: payment)

    DonationMailer.donation_email(notification_kind, payment).deliver_now
    notification.update(delivery_status: "email_success", message_channel: "email")
  end

  def calculated_notification_kind(payment)
    user = payment.user
    return "donation_standard" if user.blank?
    relevant_period = (Time.current - 50.days)..Time.current
    recovered_bikes = user.bikes.select { |b| b.stolen_recovery? }

    # Return recovered if there's a relevant recovery - higher priority than theft_alert
    if recovered_bikes.any? { |b| b.recovered_records.where(recovered_at: relevant_period).any? }
      return "donation_recovered"
    end

    # theft_alert is higher priority than anything else
    if user.theft_alerts.paid.where(created_at: relevant_period).any?
      return "donation_theft_alert"
    end

    stolen_records = user.bikes.stolen.map(&:current_stolen_record)
    if stolen_records.any? { |s| s.date_stolen > relevant_period.first }
      "donation_stolen"
    elsif user.payments.donation.where("id < ?", payment.id).any?
      "donation_second"
    else
      "donation_standard"
    end
  end
end
