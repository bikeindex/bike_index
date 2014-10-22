class EmailFeedbackNotificationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'email'
  sidekiq_options backtrace: true

  def perform(feedback_id)
    @feedback = Feedback.find(feedback_id)
    AdminMailer.feedback_notification_email(@feedback).deliver
  end

end