class Feedback < ActiveRecord::Base
  attr_accessible :body, :email, :name, :title

  validates_presence_of :body, :email, :name, :title

  after_create :notify_admins
  def notify_admins
    Resque.enqueue(FeedbackNotificationEmailJob, self.id)
  end

end
