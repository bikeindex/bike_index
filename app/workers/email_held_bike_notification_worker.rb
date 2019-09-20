class EmailHeldBikeNotificationWorker < ScheduledWorker
  def self.frequency
    24.hours
  end

  def perform
    record_scheduler_started
    notify_of_bike_index_held
    record_scheduler_finished
  end

  def notify_of_bike_index_held
    Bike.held_with_match.each do |bike, match|
      next if CustomerContact.held_bike_notification.exists?(bike_id: bike.id, user_email: bike.owner_email)

      email = CustomerMailer.held_bike_email(bike, match)
      contact = CustomerContact.build_held_bike_notification(
        bike: bike,
        subject: email.subject,
        body: email.text_part.to_s,
        sender: email.from.first,
      )

      email.deliver_now if contact.save
    end
  end
end
