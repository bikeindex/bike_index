class ScheduledSearchForExternalRegistryBikesJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    22.hours
  end

  def skip_scheduling?
    super || ENV["VERLOREN_OF_GEVONDEN_BASE_URL"].blank?
  end

  def perform
    Bike
      .currently_stolen_in(country: "NL")
      .pluck(:serial_normalized)
      .uniq
      .each { |serial| SearchForExternalRegistryBikesJob.perform_async(serial) }
  end
end
