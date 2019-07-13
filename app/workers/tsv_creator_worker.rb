class TsvCreatorWorker < ScheduledWorker
  def self.frequency
    24.hours
  end

  def perform(tsv_method = nil, true_and_false = false)
    return enqueue_scheduled_jobs if tsv_method.blank?
    require "tsv_creator"
    require "file_cache_maintainer"
    creator = TsvCreator.new
    if true_and_false
      creator.send(tsv_method, true)
      creator.send(tsv_method, false)
    else
      creator.send(tsv_method)
    end
  end

  def enqueue_scheduled_jobs
    record_scheduler_started
    TsvCreatorWorker.perform_async("create_manufacturer")
    TsvCreatorWorker.perform_async("create_daily_tsvs")
    TsvCreatorWorker.perform_in(20.minutes, "create_stolen_with_reports", true)
    TsvCreatorWorker.perform_in(1.hour, "create_stolen", true)
    record_scheduler_finished
  end
end
