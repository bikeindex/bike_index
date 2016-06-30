class StolenNotification < ActiveRecord::Base
  attr_accessible :subject,
    :reference_url,
    :message,
    :sender,
    :receiver,
    :bike_id,
    :bike,
    :receiver_email,
    :send_dates,
    :application_id

  belongs_to :bike
  belongs_to :sender, class_name: 'User', foreign_key: :sender_id
  belongs_to :receiver, class_name: 'User', foreign_key: :receiver_id

  validates_presence_of :sender, :bike, :message

  before_create :assign_receiver
  def assign_receiver
    unless self.receiver.present?
      self.receiver_email = self.bike.owner_email
      self.receiver = self.bike.owner
    end
    self.send_dates = [].to_json
  end

  after_create :notify_receiver
  def notify_receiver
    if sender.sent_stolen_notifications.count < 2 or sender.can_send_many_stolen_notifications
      EmailStolenNotificationWorker.perform_async(id)
    else
      EmailBlockedStolenNotificationWorker.perform_async(id)
    end
  end

  def default_subject
    "Stolen bike contact"
  end

  def display_subject
    subject || default_subject
  end

  def send_dates_parsed # Required for compatibility with rails 3 & 4
    return [] unless send_dates
    send_dates.is_a?(String) ? JSON.parse(send_dates) : send_dates
  end
end
