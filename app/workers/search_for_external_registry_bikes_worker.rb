class SearchForExternalRegistryBikesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.hours
  end

  def perform
    search_external_registries_for(country: "NL")
  end

  # Search external registries results are persisted as ExternalRegistryBike records
  def search_external_registries_for(country:)
    queries = Bike.currently_stolen_in(country: country).normalized_serial_stems

    ExternalRegistry.in_country(country).each do |registry|
      queries.each do |query|
        registry.search_registry(serial_number: query)
        sleep(2)
      end
    end
  end
end
