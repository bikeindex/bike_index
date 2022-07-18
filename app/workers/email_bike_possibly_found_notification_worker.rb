class EmailBikePossiblyFoundNotificationWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(bike_id, match_class, match_id)
    bike = Bike.find(bike_id)
    matched_bike = match_class.to_s.constantize.find(match_id)

    return if bike == matched_bike
    return if CustomerContact.possibly_found_notification_sent?(bike, matched_bike)

    contact = CustomerContact.build_bike_possibly_found_notification(bike, matched_bike)
    return unless contact.receives_stolen_bike_notifications?

    email = CustomerMailer.bike_possibly_found_email(contact)
    contact.email = email
    email.deliver_now if contact.save
  end
end
