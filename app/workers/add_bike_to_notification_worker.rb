# Notification.without_bike.where(kind: AddBikeToNotificationWorker.bike_kinds).pluck(:id).each { |i| AddBikeToNotificationWorker.perform_async(i) }

class AddBikeToNotificationWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: false

  def self.bike_kinds
    %w[donation_recovered donation_stolen donation_theft_alert] +
      Notification.impound_claim_kinds + Notification.theft_alert_kinds
  end

  def perform(id)
    notification = Notification.find(id)
    return unless notification.present? && notification.bike_id.blank?
    bike = bike_for_notification(notification)
    return unless bike.present?
    notification.update(bike: bike)
  end

  def relevant_period(obj = nil)
    time = obj&.created_at || Time.current
    (time - 50.days)..(time + 1.day)
  end

  def bike_for_notification(notification)
    if notification.theft_alert?
      notification.notifiable&.bike
    elsif notification.impound_claim?
      notification.notifiable&.bike_claimed
    elsif notification.kind == "donation_recovered"
      matching_recovered_bikes(notification).last
    elsif notification.kind == "donation_stolen"
      matching_stolen_bikes(notification).last
    elsif notification.kind == "donation_theft_alert"
      matching_theft_alert_bikes(notification).last
    end
  end

  def matching_recovered_bikes(notification)
    return [] if notification.user.blank?
    notification.user.bikes.select do |b|
      b.stolen_recovery? && b.recovered_records.where(recovered_at: relevant_period(notification)).any?
    end.sort do |a, b|
      # most recent recovery
      a.recovered_records.last.recovered_at <=> b.recovered_records.last.recovered_at
    end
  end

  def matching_stolen_bikes(notification)
    return [] if notification.user.blank?
    notification.user.bikes.status_stolen.map(&:current_stolen_record).reject(&:blank?)
      .select { |s| relevant_period(notification).include?(s.date_stolen) }
      .sort_by(&:date_stolen) # most recent stolen
      .map(&:bike)
  end

  def matching_theft_alert_bikes(notification)
    return [] if notification.user.blank?
    notification.user.theft_alerts.paid.where(created_at: relevant_period(notification)).order(:created_at)
      .map(&:bike)
  end
end
