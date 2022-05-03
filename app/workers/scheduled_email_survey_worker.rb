class ScheduledEmailSurveyWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options retry: 2
  SURVEY_COUNT = (ENV["THEFT_SURVEY_COUNT"] || 200).to_i

  def self.frequency
    24.hours
  end

  def perform(stolen_record_id = nil, force_send = false)
    return enqueue_workers(SURVEY_COUNT) if stolen_record_id.blank?
    stolen_record = StolenRecord.unscoped.find(stolen_record_id)
    return if !force_send && no_survey?(stolen_record)
    notification = Notification.create(kind: :theft_survey_4_2022, notifiable: stolen_record,
      user: stolen_record.user)
    CustomerMailer.theft_survey(notification).deliver_now
    notification.update(delivery_status: "email_success", message_channel: "email")
  end

  def send_survey?(stolen_record = nil)
    return false unless stolen_record.present? && !stolen_record.no_notify? &&
      survey_period.cover?(stolen_record.date_stolen)
    user = stolen_record.user
    user.present? && user.notifications.theft_survey.none?
  end

  def no_survey?(stolen_record)
    !send_survey?(stolen_record)
  end

  def enqueue_workers(enqueue_limit)
    potential_stolen_records.limit(enqueue_limit).find_each do |stolen_record|
      next if no_survey?(stolen_record)
      ScheduledEmailSurveyWorker.perform_async(stolen_record.id)
    end
  end

  # Split out to make it easier to individually send messages
  def potential_stolen_records
    StolenRecord.unscoped.where(no_notify: false, date_stolen: survey_period)
      .left_joins(:theft_surveys).where(notifications: {notifiable_id: nil})
      .where(country_id: [nil, Country.united_states.id, Country.canada.id])
      .reorder(Arel.sql("random()"))
  end

  def survey_period
    (Time.current - 3.years)..(Time.current - 4.weeks)
  end
end
