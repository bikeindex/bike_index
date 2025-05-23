class ScheduledBikePossiblyFoundNotificationJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    23.hours
  end

  def perform
    bikes_with_matches.each do |bike, match|
      Email::BikePossiblyFoundNotificationJob
        .perform_async(bike.id, match.class.to_s, match.id)
    end
  end

  def bikes_with_matches
    internal_matches = Bike.possibly_found_with_match
    external_matches = Bike.possibly_found_externally_with_match
    internal_matches.concat(external_matches)
  end
end
