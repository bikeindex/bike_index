class TsvCreatorJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    24.hours
  end

  def perform(tsv_method = nil, true_and_false = false)
    if tsv_method.blank?
      enqueue_scheduled_jobs
    else
      create_tsv(tsv_method, true_and_false)
    end
  end

  def create_tsv(tsv_method, true_and_false)
    creator = TsvCreator.new

    if true_and_false
      creator.send(tsv_method, true)
      creator.send(tsv_method, false)
    else
      creator.send(tsv_method)
    end
  end

  def enqueue_scheduled_jobs
    TsvCreatorJob.perform_async("create_manufacturer")
    TsvCreatorJob.perform_async("create_daily_tsvs")
    TsvCreatorJob.perform_in(20.minutes, "create_stolen_with_reports", true)
    TsvCreatorJob.perform_in(1.hour, "create_stolen", true)
  end
end
