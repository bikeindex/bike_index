class Feedback < ActiveRecord::Base
  attr_accessible :body, :email, :name, :title, :feedback_type, :feedback_hash

  validates_presence_of :body, :email, :name, :title
  serialize :feedback_hash

  after_create :notify_admins
  def notify_admins
    Resque.enqueue(FeedbackNotificationEmailJob, self.id)
  end

end
