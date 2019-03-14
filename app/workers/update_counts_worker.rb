class UpdateCountsWorker < ScheduledWorker
  def self.frequency
    1.hours
  end

  def perform
    record_scheduler_started
    
    record_scheduler_finished
  end
end
