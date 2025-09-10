class Email::ScheduledSurveyJob < ScheduledJob
  prepend ScheduledJobRecorder
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
    notification.track_email_delivery do
      CustomerMailer.theft_survey(notification).deliver_now
    end
  end

  def send_survey?(bike = nil)
    return false if bike.blank?
    if bike.user_id.present?
      return false if notifications.where(user_id: bike.user_id).limit(1).any?
      return false if bike.user&.no_non_theft_notification
    end
    # Verify there are no theft survey notifications with the email
    return false if notifications.where(message_channel_target: bike.owner_email).limit(1).any?
    # Update 2024-5 -> only sending to stolen registrants
    potential_stolen_records.where(bike_id: bike.id).any?
  end

  def no_survey?(bike)
    !send_survey?(bike)
  end

  def enqueue_workers(enqueue_limit)
    return if enqueue_limit == 0
    # Some "potential" bikes that are no_survey, so add 200 to cover
    enqueue_count = enqueue_limit + 200
    sent = 0
    potential_recovered_bikes.limit(enqueue_count).find_each do |bike|
      next if no_survey?(bike)
      break if sent > enqueue_limit
      Email::ScheduledSurveyJob.perform_in((enqueue_count + sent) * 5, bike.id)
      sent += 1
    end
    potential_stolen_bikes.limit(enqueue_count - sent).find_each do |bike|
      next if no_survey?(bike)
      break if sent > enqueue_limit
      Email::ScheduledSurveyJob.perform_in((enqueue_count + sent) * 5, bike.id)
      sent += 1
    end
  end

  def stolen_survey_period
    (Time.current - 10.years)..(Time.current - 1.week)
  end

  # Split out to make it easier to individually send messages
  def potential_stolen_bikes
    unsurveyed_bikes.joins(:stolen_records).merge(potential_stolen_records)
  end

  def potential_recovered_bikes
    unsurveyed_bikes.joins(:recovered_records).merge(potential_stolen_records)
  end

  private

  def notifications
    Notification.theft_survey
  end

  def unsurveyed_bikes
    Bike.unscoped.left_joins(:theft_surveys).where(notifications: {bike_id: nil})
  end

  # Split out to make it easier to individually send messages
  def potential_stolen_records
    StolenRecord.unscoped.where(no_notify: false, date_stolen: stolen_survey_period)
      .where(country_id: [nil, Country.united_states_id, Country.canada_id])
  end
end
