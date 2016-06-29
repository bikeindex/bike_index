class EmailStolenBikeAlertWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(customer_contact_id)
    customer_contact = CustomerContact.find(customer_contact_id)
    if customer_contact.bike.current_stolen_record.present?
      return true unless customer_contact.bike.current_stolen_record.receive_notifications
    end
    CustomerMailer.stolen_bike_alert_email(customer_contact).deliver_now
  end
end
