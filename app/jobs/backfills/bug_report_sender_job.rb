# frozen_string_literal: true

module Backfills
  # Re-attribute the bug reports the mailbox recorded as being from us, back before it read
  # Reply-To. Only the reports whose inbound email is still around can be backfilled - Action
  # Mailbox incinerates them after 30 days
  class BugReportSenderJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      # Small batches - reading a report's mail holds its whole raw email, attachments and all
      bug_reports.find_each(batch_size: 100) do |bug_report|
        email, from_name = sender_for(bug_report.inbound_email)
        next if email.blank? || email == bug_report.email

        # user_id resolved to our own account - nil lets the model re-derive it from the real sender
        bug_report.update!(email:, from_name:, user_id: nil)
      end
    end

    private

    def bug_reports
      BugReport.where("email LIKE ?", "%@#{BugReport::OUR_EMAIL_DOMAIN}").where.not(inbound_email_id: nil)
        .includes(inbound_email: {raw_email_attachment: :blob})
    end

    # A blob can go missing without its inbound email row - skip rather than stall the backfill
    def sender_for(inbound_email)
      BugReport.sender_from_mail(inbound_email.mail)
    rescue ActiveStorage::FileNotFoundError
      nil
    end
  end
end
