class ScheduledEmailSurveyWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options retry: 2
  SURVEY_COUNT = (ENV["THEFT_SURVEY_COUNT"] || 200).to_i

  def self.frequency
    24.hours
  end

  def perform(bike_id = nil, force_send = false)
    return enqueue_workers(SURVEY_COUNT) if bike_id.blank?
    bike = Bike.unscoped.find(bike_id)
    return if !force_send && no_survey?(bike)
    notification = Notification.create(kind: :theft_survey_2023, notifiable: bike, user: bike.user)
    CustomerMailer.theft_survey(notification).deliver_now
    notification.update(delivery_status: "email_success", message_channel: "email")
  end

  def send_survey?(bike = nil)
    return false unless bike.present? && bike.owner.present?
    bike.owner.notifications.theft_survey.none?
  end

  def no_survey?(bike)
    !send_survey?(bike)
  end

  def enqueue_workers(enqueue_limit)
    potential_bikes.limit(enqueue_limit).find_each do |bike|
      next if no_survey?(bike)
      ScheduledEmailSurveyWorker.perform_async(bike.id)
    end
  end

  # Split out to make it easier to individually send messages
  def potential_bikes
    Bike.unscoped.where(creation_organization_id: organizations_emailing.pluck(:id))
      .left_joins(:theft_surveys).where(notifications: {bike_id: nil})
      .reorder(Arel.sql("random()"))
  end

  def organizations_emailing
    Organization.where(opted_into_theft_survey_2023: true)
  end
end
