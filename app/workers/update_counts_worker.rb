class UpdateCountsWorker < ScheduledWorker
  def self.frequency
    1.hours
  end

  def perform
    record_scheduler_started
    Counts.count_keys.each { |k| Counts.send("assign_#{k}") }
    record_scheduler_finished
  end
end
