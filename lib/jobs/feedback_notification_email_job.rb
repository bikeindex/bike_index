class FeedbackNotificationEmailJob
  @queue = "email"

  def self.perform(feedback_id)
    @feedback = Feedback.find(feedback_id)
    AdminMailer.feedback_notification_email(@feedback).deliver
  end

end