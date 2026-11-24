# frozen_string_literal: true

module Backfills
  # Link bug reports sent before their sender's account was created or confirmed, which
  # AfterUserCreateJob now does as it happens
  class BugReportUserJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      BugReport.where(user_id: nil).find_each do |bug_report|
        user = User.fuzzy_email_find(bug_report.email)
        bug_report.update(user:) if user.present?
      end
    end
  end
end
