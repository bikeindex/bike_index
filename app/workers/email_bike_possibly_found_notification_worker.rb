class EmailBikePossiblyFoundNotificationWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.hours
  end

  def perform
    Bike
      .possibly_found_with_match
      .concat(Bike.possibly_found_externally_with_match)
      .each { |bike, match| send_bike_possibly_found_notification(bike, match) }
  end

  def send_bike_possibly_found_notification(bike, match)
    return if CustomerContact.possibly_found_notification_sent?(bike, match)

    contact = CustomerContact.build_bike_possibly_found_notification(bike, match)
    return unless contact.receives_stolen_bike_notifications?

    email = CustomerMailer.bike_possibly_found_email(contact)
    contact.email = email
    email.deliver_now if contact.save
  end
end
