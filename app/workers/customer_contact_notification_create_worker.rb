class CustomerContactNotificationCreateWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3 # If it fails, probably will fail more

  def perform(customer_contact_id)
    customer_contact = CustomerContact.find_by_id(customer_contact_id)
    return if customer_contact.blank? || !customer_contact.receives_stolen_bike_notifications?

    notification = customer_contact.notification || Notification.create(notifiable: customer_contact,
      user_id: customer_contact.user_id,
      bike_id: customer_contact.bike_id,
      kind: customer_contact.kind)

    notification.track_email_delivery do
      CustomerMailer.stolen_bike_alert_email(customer_contact).deliver_now
    end
    # Bump the bike to break caches
    customer_contact.bike.update(updated_at: Time.current) if customer_contact.bike.present?
  end
end
