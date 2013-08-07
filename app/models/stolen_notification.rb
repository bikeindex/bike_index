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
    Resque.enqueue(StolenNotificationEmailJob, self.id)
  end

end
