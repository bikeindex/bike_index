# frozen_string_literal: true

class Email::FeedbackNotificationJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 1

  def perform(feedback_id)
    @feedback = Feedback.find(feedback_id)
    AdminMailer.feedback_notification_email(@feedback).deliver_now
  end
end
