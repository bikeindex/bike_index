class EnqueueSearchForExternalRegistryBikesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.hours
  end

  def perform
    Bike
      .currently_stolen_in(country: "NL")
      .pluck(:serial_normalized)
      .uniq
      .each { |serial| SearchForExternalRegistryBikesWorker.perform_async(serial) }
  end
end
