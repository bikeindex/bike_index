# frozen_string_literal: true

module Backfills
  # Set receiver on the bug reports created before the mailbox recorded it. Only the reports whose
  # inbound email is still around can be backfilled - Action Mailbox incinerates them after 30 days
  class BugReportReceiverJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      bug_reports.find_each do |bug_report|
        receiver = receiver_for(bug_report.inbound_email)
        next if receiver.blank?

        # update_column so the report's user_id and membership snapshot stay as they were
        bug_report.update_column(:receiver, receiver)
      end
    end

    private

    def bug_reports
      BugReport.where(receiver: nil).where.not(inbound_email_id: nil).includes(:inbound_email)
    end

    # A blob can go missing without its inbound email row - skip rather than stall the backfill
    def receiver_for(inbound_email)
      EmailReceiver.for_mail(inbound_email.mail)
    rescue ActiveStorage::FileNotFoundError
      nil
    end
  end
end
