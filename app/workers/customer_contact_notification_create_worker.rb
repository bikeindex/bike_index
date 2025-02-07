class CustomerContactNotificationCreateWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 3 # If it fails, probably will fail more

  def perform(customer_contact_id)
    customer_contact = CustomerContact.find_by_id(customer_contact_id)
    return true if customer_contact.blank? || customer_contact.notification.present?
    Notification.create(notifiable: customer_contact,
      delivery_status_str: "email_success",
      user_id: customer_contact.user_id,
      bike_id: customer_contact.bike_id,
      kind: customer_contact.kind)
    # Bump the bike to break caches
    customer_contact.bike.update(updated_at: Time.current) if customer_contact.bike.present?
  end
end
