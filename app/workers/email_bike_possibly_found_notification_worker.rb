class EmailBikePossiblyFoundNotificationWorker < ScheduledWorker
  def self.frequency
    24.hours
  end

  def perform
    record_scheduler_started
    notify_of_bike_index_held
    record_scheduler_finished
  end

  def notify_of_bike_index_held
    Bike.possibly_found_with_match.each do |bike, match|
      next if CustomerContact.bike_possibly_found.exists?(bike_id: bike.id, user_email: bike.owner_email)

      email = CustomerMailer.bike_possibly_found_email(bike, match)
      contact = CustomerContact.build_bike_possibly_found_notification(
        bike: bike,
        subject: email.subject,
        body: email.text_part.to_s,
        sender: email.from.first,
      )

      if contact.should_be_sent? && contact.save
        email.deliver_now
      end
    end
  end
end
