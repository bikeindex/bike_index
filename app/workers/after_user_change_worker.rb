class AfterUserChangeWorker < ApplicationWorker
  sidekiq_options retry: false

  def perform(user_id, user = nil)
    user ||= User.find_by_id(user_id)
    return false unless user.present?

    add_phones_for_verification(user)

    current_alerts = user_general_alerts(user)
    unless user.general_alerts == current_alerts
      user.update_attributes(general_alerts: current_alerts, skip_update: true)
    end
  end

  def user_general_alerts(user)
    alerts = []

    alerts << "phone_waiting_confirmation" if user.phone_waiting_confirmation?

    # Ignore alerts below for superusers
    return alerts if user.superuser

    if user.rough_stolen_bikes.any? { |b| b&.current_stolen_record&.theft_alert_missing_photo? }
      alerts << "theft_alert_without_photo"
    end

    return alerts if user.memberships.admin.any?

    if user.rough_stolen_bikes.any? { |b| b&.current_stolen_record&.without_location? }
      alerts << "stolen_bikes_without_locations"
    end

    alerts.sort
  end

  def add_phones_for_verification(user)
    return false if user.phone.blank?
    return false if user.user_phones.unscoped.where(phone: user.phone).present?
    user_phone = user.user_phones.create!(phone: user.phone)
    # Run this in the same process, rather than a different worker, so we update the general alerts
    UserPhoneConfirmationWorker.new.perform(user_phone.id, false)
    user.reload
    true
  end
end
