class AfterUserChangeWorker < ApplicationWorker
  sidekiq_options retry: false

  def perform(user_id)
    user = User.find_by_id(user_id)
    return false unless user.present?

    current_alerts = user_general_alerts(user)
    unless user.general_alerts == current_alerts
      user.update_attributes(general_alerts: current_alerts)
    end
  end

  def user_general_alerts(user)
    alerts = []
    return alerts if user.superuser # No alerts for superusers

    if user.rough_stolen_bikes.any? { |b| b&.current_stolen_record&.theft_alert_missing_photo? }
      alerts << "theft_alert_without_photo"
    end

    return alerts if user.memberships.admin.any?

    if user.rough_stolen_bikes.any? { |b| b&.current_stolen_record&.missing_location? }
      alerts << "stolen_bikes_without_locations"
    end

    alerts.sort
  end
end
