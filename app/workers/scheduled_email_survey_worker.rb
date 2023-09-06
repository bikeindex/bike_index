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
    notification = Notification.create(kind: :theft_survey_2023, bike: bike, user: bike.user)
    CustomerMailer.theft_survey(notification).deliver_now
    notification.update(delivery_status: "email_success", message_channel: "email")
  end

  def notifications
    Notification.theft_survey_2023
  end

  def send_survey?(bike = nil)
    return false if bike.blank?
    if bike.user_id.present?
      return false if notifications.where(user_id: bike.user_id).limit(1).any?
      return false if bike.user&.no_non_theft_notification
    end
    # Verify there are no theft survey notifications with the email
    notifications.where(message_channel_target: bike.owner_email).limit(1).none?
  end

  def no_survey?(bike)
    !send_survey?(bike)
  end

  def enqueue_workers(enqueue_limit)
    # There are some "potential" bikes that are no_survey, so add 200 to cover
    unclaimed_count = enqueue_limit + 200 - potential_bikes.claimed.count
    potential_bikes.claimed.limit(enqueue_limit).find_each do |bike|
      next if no_survey?(bike)
      ScheduledEmailSurveyWorker.perform_async(bike.id)
    end
    return if unclaimed_count < 0
    potential_bikes.unclaimed.limit(unclaimed_count).find_each do |bike|
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
