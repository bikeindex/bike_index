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
    return true if no_notification_types.include?(feedback_type)
    EmailFeedbackNotificationWorker.perform_async(id)
  end

  def no_notification_types
    ['manufacturer_update_request', 'serial_update_request']
  end

end
