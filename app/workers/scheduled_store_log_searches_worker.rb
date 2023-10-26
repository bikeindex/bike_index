class ScheduledStoreLogSearchesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    1.minute
  end

  def perform
  end
end
