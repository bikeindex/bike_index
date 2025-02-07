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
      bike: bike_for_notification(payment, notification_kind))

    DonationMailer.donation_email(notification_kind, payment).deliver_now
    notification.update(delivery_status_str: "email_success", message_channel: "email")
  end

  def calculated_notification_kind(payment)
    user = payment.user
    return "donation_standard" if user.blank?

    # Return recovered if there's a relevant recovery - higher priority than theft_alert
    if matching_recovered_bikes(payment).any?
      return "donation_recovered"
    end

    # theft_alert is higher priority than anything else
    if user.theft_alerts.paid.where(created_at: relevant_period(payment)).any?
      return "donation_theft_alert"
    end

    if matching_stolen_bikes(payment).any?
      "donation_stolen"
    elsif user.payments.donation.where("id < ?", payment.id).any?
      "donation_second"
    else
      "donation_standard"
    end
  end

  def relevant_period(obj = nil)
    time = obj&.created_at || Time.current
    (time - 50.days)..(time + 1.day)
  end

  def bike_for_notification(payment, notification_kind)
    if notification_kind == "donation_recovered"
      matching_recovered_bikes(payment).last
    elsif notification_kind == "donation_stolen"
      matching_stolen_bikes(payment).last
    elsif notification_kind == "donation_theft_alert"
      matching_theft_alert_bikes(payment).last
    end
  end

  def matching_recovered_bikes(payment)
    return [] if payment.user.blank?
    payment.user.bikes.select do |b|
      b.stolen_recovery? && b.recovered_records.where(recovered_at: relevant_period(payment)).any?
    end.sort do |a, b|
      # most recent recovery
      a.recovered_records.last.recovered_at <=> b.recovered_records.recovered_at
    end
  end

  def matching_stolen_bikes(payment)
    return [] if payment.user.blank?
    payment.user.bikes.status_stolen.map(&:current_stolen_record).reject(&:blank?)
      .select { |s| relevant_period(payment).cover?(s.date_stolen) }
      .sort_by(&:date_stolen) # most recent stolen
      .map(&:bike)
  end

  def matching_theft_alert_bikes(payment)
    return [] if payment.user.blank?
    payment.user.theft_alerts.paid.where(created_at: relevant_period(payment)).order(:created_at)
      .map(&:bike)
  end
end
