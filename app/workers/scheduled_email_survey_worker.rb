class ScheduledEmailSurveyWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options retry: 1
  SURVEY_COUNT = (ENV["THEFT_SURVEY"] || 200).to_i

  def self.frequency
    24.hours
  end

  def perform(stolen_record_id = nil, force_send = false)
    return enqueue_workers if stolen_record_id.blank?
    stolen_record = StolenRecord.unscoped.find(stolen_record_id)
    return if !force_send && no_survey?(stolen_record)
    # In case something got enqueued in between
    pp "sending!!!"
  end

  def send_survey?(stolen_record = nil)
    return false unless stolen_record.present? && !stolen_record.no_notify? &&
      survey_period.cover?(stolen_record.date_stolen)
    user = stolen_record.user
    user.present? && user.notifications.theft_surveys.none?
  end

  def no_survey?(stolen_record)
    !send_survey?(stolen_record)
  end

  def enqueue_workers
    StolenRecord.unscoped.where(no_notify: false, date_stolen: survey_period)
      .left_joins(:theft_surveys).where(notifications: {notifiable_id: nil})
      .order(:updated_at).limit(SURVEY_COUNT)
      .find_each do |stolen_record|
        next if no_survey?(stolen_record)
        ScheduledEmailSurveyWorker.perform_async(stolen_record.id)
      end
  end

  def survey_period
    (Time.current - 8.weeks)..(Time.current - 4.weeks)
  end
end
