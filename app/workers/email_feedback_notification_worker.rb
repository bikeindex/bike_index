class EmailFeedbackNotificationWorker
  include Sidekiq::Worker
  sidekiq_options queue: "notify", backtrace: true, retry: 1

  def perform(feedback_id)
    # @feedback = Feedback.find(feedback_id)
    # AdminMailer.feedback_notification_email(@feedback).deliver_now
  end
end
