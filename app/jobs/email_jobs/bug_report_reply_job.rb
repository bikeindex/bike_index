# frozen_string_literal: true

module EmailJobs
  class BugReportReplyJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    # The message is an argument rather than stored, so nothing keeps it once it's sent
    def perform(notification_id, message)
      notification = Notification.find_by(id: notification_id)
      return if notification.blank?

      Notifications::Deliver.track_email(notification) do
        CustomerMailer.bug_report_reply(notification, message).deliver_now
      end
      # The bug reports table caches its rows on the report, and shows whether it was replied to
      notification.notifiable&.touch
    end
  end
end
