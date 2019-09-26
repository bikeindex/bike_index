class SearchForExternalRegistryBikesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.hours
  end

  def perform
    search_dutch_impounded_registry
  end

  # Search external registries results are persisted as ExternalRegistryBike records
  def search_dutch_impounded_registry
    serials = Bike.currently_stolen_in(country: "NL").select(:serial_normalized)
    serials_count = serials.pluck(:serial_normalized).count
    queries = serials.normalized_serial_stems
    registry = ExternalRegistry.verloren_of_gevonden

    Rails.logger.info("Querying #{registry.name} for #{queries.count} stems (of #{serials_count} serials)")

    Thread.abort_on_exception = true

    queries.each.with_index(1) do |query, i|
      Rails.logger.info("[#{registry.name}] query: '#{query}' (#{i} of #{queries.length})")
      registry.search_registry(serial_number: query)
    end
  end
end
