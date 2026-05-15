# frozen_string_literal: true

module Email
  class BikePossiblyFoundNotificationJob < ApplicationJob
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
      return unless contact.save

      notification = contact.notification || Notification.create(notifiable: contact,
        user_id: contact.user_id,
        bike_id: contact.bike_id,
        kind: contact.kind)

      notification.track_email_delivery { email.deliver_now }
    end
  end
end
