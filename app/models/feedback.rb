class Feedback < ActiveRecord::Base
  attr_accessible :body,
    :email,
    :name,
    :title,
    :feedback_type,
    :feedback_hash

  validates_presence_of :body, :email, :title
  serialize :feedback_hash

  after_create :notify_admins
  def notify_admins
    EmailFeedbackNotificationWorker.perform_async(id)
  end

end
