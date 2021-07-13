class CustomerContactNotificationCreateWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 3 # If it fails, probably will fail more

  # TODO: remove legacy_migration, post #2013
  def perform(customer_contact_id, legacy_migration = false)
    customer_contact = CustomerContact.find_by_id(customer_contact_id)
    return true if customer_contact.blank? || customer_contact.notification.present?
    notification = Notification.create(notifiable: customer_contact,
      delivery_status: "email_success",
      user_id: customer_contact.user_id,
      bike_id: customer_contact.bike_id,
      kind: customer_contact.kind)
    notification.update(created_at: customer_contact.created_at) if legacy_migration
  end
end
