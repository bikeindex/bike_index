# frozen_string_literal: true

module Backfills
  # Set message_id on the bug reports created before the mailbox recorded it, from the inbound
  # emails Action Mailbox hasn't incinerated yet
  class BugReportMessageIdJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      BugReport.where(message_id: nil).joins(:inbound_email)
        .update_all("message_id = action_mailbox_inbound_emails.message_id")
    end
  end
end
