class FetchProject529BikesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.hours
  end

  def perform
    ExternalRegistry::Project529Client.bikes
  end
end
