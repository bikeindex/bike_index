class StolenNotification < ActiveRecord::Base
  attr_accessible :subject,
    :message,
    :sender,
    :receiver,
    :bike_id,
    :bike

  belongs_to :bike
  belongs_to :sender, class_name: 'User', foreign_key: :sender_id
  belongs_to :receiver, class_name: 'User', foreign_key: :receiver_id

  validates_presence_of :sender, :bike, :message

  before_create :assign_receiver
  def assign_receiver
    unless self.receiver.present?
      self.receiver = self.bike.owner
    end
  end

  after_create :notify_receiver
  def notify_receiver
    if sender.sent_stolen_notifications.count < 2 or sender.can_send_many_stolen_notifications
      Resque.enqueue(StolenNotificationEmailJob, self.id)
    else
      Resque.enqueue(BlockedStolenNotificationEmailJob, self.id)
    end
  end

end
