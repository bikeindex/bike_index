class SearchForExternalRegistryBikesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.hours
  end

  def perform
  end

  def normalized_serial_stems
  end

  def search_external_registries
  end
end
