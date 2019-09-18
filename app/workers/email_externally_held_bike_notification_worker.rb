class EmailExternallyHeldBikeNotificationWorker < ScheduledWorker
  def self.frequency
    24.hours
  end

  def perform
    record_scheduler_started
    notify_of_external_registry_held
    record_scheduler_finished
  end

  def notify_of_external_registry_held
    potential_externally_held = Bike.stolen.where.not(id: Bike.abandoned.select(:id))

    potential_externally_held.find_each do |bike|
      already_sent = CustomerContact.externally_held_bike_notification.exists?(bike_id: bike.id, user_email: bike.owner_email)
      next if already_sent

      client = ExternalRegistries::VerlorenOfGevondenClient.new
      results = client.search(bike.serial_normalized.to_s)

      match = results.select { |res| res.serial_number == bike.serial_normalized }
      next if match.blank?

      email = CustomerMailer.held_bike_email(bike, match)
      contact = CustomerContact.build_externally_held_bike_notification(
        bike: bike,
        subject: email.subject,
        body: email.text_part.to_s,
        sender: email.from.first,
      )

      email.deliver_now if contact.save
    end
  end
end
