class EmailBikePossiblyFoundNotificationWorker < ApplicationWorker
  def perform(bike_id, match_class, match_id)
    bike = Bike.find(bike_id)
    match = match_class.to_s.constantize.find(match_id)

    return if bike == match
    return if CustomerContact.possibly_found_notification_sent?(bike, match)

    contact = CustomerContact.build_bike_possibly_found_notification(bike, match)
    return unless contact.receives_stolen_bike_notifications?

    email = CustomerMailer.bike_possibly_found_email(contact)
    contact.email = email
    email.deliver_now if contact.save
  end
end
