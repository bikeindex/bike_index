class StolenNotification < ApplicationRecord
  belongs_to :bike
  belongs_to :sender, class_name: "User", foreign_key: :sender_id
  belongs_to :receiver, class_name: "User", foreign_key: :receiver_id

  validates_presence_of :sender, :bike, :message

  before_validation :set_calculated_attributes

  after_create :notify_receiver

  def notify_receiver
    EmailStolenNotificationWorker.perform_async(id)
  end

  def permitted_send?
    return false unless bike.contact_owner?(sender)
    return true if sender.send_unstolen_notifications?
    sender.sent_stolen_notifications.count < 2 or sender.can_send_many_stolen_notifications
  end

  def unstolen_blocked?
    !bike.stolen? && !bike.contact_owner?(sender)
  end

  def send_dates_parsed # Required for compatibility with rails 3 & 4
    return [] unless send_dates
    send_dates.is_a?(String) ? JSON.parse(send_dates) : send_dates
  end

  def set_calculated_attributes
    self.receiver_email ||= bike&.contact_owner_email
    self.receiver ||= bike.owner
    self.send_dates ||= [].to_json
  end

  def default_message
    self.message ||= <<~STR
      Hi, this is #{sender&.name} with Bike Index.
      Is this your missing #{bike.type}?
    STR
  end
end
