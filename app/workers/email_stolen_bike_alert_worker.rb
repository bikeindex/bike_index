class EmailStolenBikeAlertWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(customer_contact_id)
    customer_contact = CustomerContact.find(customer_contact_id)

    if customer_contact.stolen_record_receives_notifications?
      CustomerMailer.stolen_bike_alert_email(customer_contact).deliver_now
    end
  end
end
