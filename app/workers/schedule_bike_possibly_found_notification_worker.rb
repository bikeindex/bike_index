class ScheduleBikePossiblyFoundNotificationWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.hours
  end

  def perform
    bikes_with_matches.each do |bike, match|
      EmailBikePossiblyFoundNotificationWorker
        .perform_async(bike.id, match.class.to_s, match.id)
    end
  end

  def bikes_with_matches
    internal_matches = Bike.possibly_found_with_match
    external_matches = Bike.possibly_found_externally_with_match
    internal_matches.concat(external_matches)
  end
end
