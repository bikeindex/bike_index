class EmailDonationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(id)
    payment = Payment.find(id)
    return unless payment.present? && payment.donation?
    @user = payment.user
    notification_kind = calculated_notification_kind(payment)
    notification = payment.notifications.where(kind: notification_kind).first
    # If already delivered, skip out!
    return true if notification&.delivered?
    notification ||= Notification.create(kind: notification_kind, notifiable: payment,
        bike_id: bike_for_notification(payment.user, notification_kind)&.id)

    DonationMailer.donation_email(notification_kind, payment).deliver_now
    notification.update(delivery_status: "email_success", message_channel: "email")
  end

  def relevant_period
    (Time.current - 50.days)..Time.current
  end

  def calculated_notification_kind(payment)
    user = payment.user
    return "donation_standard" if user.blank?

    # Return recovered if there's a relevant recovery - higher priority than theft_alert
    if matching_recovered_bikes(user).any?
      return "donation_recovered"
    end

    # theft_alert is higher priority than anything else
    if user.theft_alerts.paid.where(created_at: relevant_period).any?
      return "donation_theft_alert"
    end

    if matching_stolen_bikes(user).any?
      "donation_stolen"
    elsif user.payments.donation.where("id < ?", payment.id).any?
      "donation_second"
    else
      "donation_standard"
    end
  end

  def bike_for_notification(user, notification_kind)
    if notification_kind == "donation_recovered"
      matching_recovered_bikes(user).last
    elsif notification_kind == "donation_stolen"
      matching_stolen_bikes(user).last
    elsif notification_kind == "donation_theft_alert"
      matching_theft_alert_bikes(user).last
    end
  end

  def matching_recovered_bikes(user = nil)
    return [] if user.blank?
    user.bikes.select do |b|
      b.stolen_recovery? && b.recovered_records.where(recovered_at: relevant_period).any?
    end.sort do |a, b|
      # most recent recovery
      a.recovered_records.last.recovered_at <=> b.recovered_records.recovered_at
    end
  end

  def matching_stolen_bikes(user = nil)
    return [] if user.blank?
    stolen_records = user.bikes.status_stolen.map(&:current_stolen_record).reject(&:blank?)
    stolen_records.select { |s| s.date_stolen.present? && relevant_period.include?(s.date_stolen) }
      .sort { |a, b| a.date_stolen <=> b.date_stolen } # most recent stolen
      .map(&:bike)
  end

  def matching_theft_alert_bikes(user)
    user.theft_alerts.paid.where(created_at: relevant_period).order(:created_at)
      .map(&:bike)
  end
end
