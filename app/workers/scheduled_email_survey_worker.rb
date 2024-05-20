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
    Notification.theft_survey
  end

  def send_survey?(bike = nil)
    return false if bike.blank?
    if bike.user_id.present?
      return false if notifications.where(user_id: bike.user_id).limit(1).any?
      return false if bike.user&.no_non_theft_notification
    end
    # Verify there are no theft survey notifications with the email
    return false if notifications.where(message_channel_target: bike.owner_email).limit(1).any?
    matching_stolen_records = bike.stolen_records.where(date_stolen: stolen_survey_period)
    matching_stolen_records.any?
  end

  def no_survey?(bike)
    !send_survey?(bike)
  end

  def enqueue_workers(enqueue_limit)
    return if enqueue_limit == 0
    # There are some "potential" bikes that are no_survey, so add 200 to cover
    unclaimed_count = enqueue_limit + 200 - potential_bikes.claimed.count
    potential_bikes.claimed.limit(enqueue_limit).each_with_index do |bike, index|
      next if no_survey?(bike)
      ScheduledEmailSurveyWorker.perform_in(index * 5, bike.id)
    end
    return if unclaimed_count < 0
    potential_bikes.unclaimed.limit(unclaimed_count).each_with_index do |bike, index|
      next if no_survey?(bike)
      ScheduledEmailSurveyWorker.perform_in((unclaimed_count + index) * 5, bike.id)
    end
  end

  # Split out to make it easier to individually send messages
  def potential_stolen_records
    StolenRecord.unscoped.where(no_notify: false, date_stolen: survey_period)
      .left_joins(:theft_surveys).where(notifications: {notifiable_id: nil})
      .where(country_id: [nil, Country.united_states.id, Country.canada.id])
  end

  def stolen_survey_period
    (Time.current - 5.years)..(Time.current - 2.weeks)
  end

  # Split out to make it easier to individually send messages
  def potential_bikes
    Bike.unscoped.left_joins(:theft_surveys).where(notifications: {bike_id: nil})
      .merge(potential_stolen_records)
      .reorder(Arel.sql("random()"))
  end

  def organizations_emailing
    Organization.where(opted_into_theft_survey_2023: true)
  end
end
