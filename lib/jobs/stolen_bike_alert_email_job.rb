class StolenBikeAlertEmailJob
  @queue = "email"

  def self.perform(customer_contact_id)
    customer_contact = CustomerContact.find(customer_contact_id)
    if customer_contact.bike.current_stolen_record.present?
      return true unless customer_contact.bike.current_stolen_record.receive_notifications
    end
    CustomerMailer.stolen_bike_alert_email(customer_contact).deliver
  end
end
