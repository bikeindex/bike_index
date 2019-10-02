class EmailBikePossiblyFoundNotificationWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.hours
  end

  def perform
    notify_of_bike_index_held
  end

  def notify_of_bike_index_held
    Bike.possibly_found_with_match.each do |bike, match|
      next if CustomerContact.possibly_found_notification_sent?(bike, match)

      contact = CustomerContact.build_bike_possibly_found_notification(bike, match)
      next unless contact.receives_stolen_bike_notifications?

      email = CustomerMailer.bike_possibly_found_email(contact)
      contact.email = email
      email.deliver_now if contact.save
    end
  end
end
