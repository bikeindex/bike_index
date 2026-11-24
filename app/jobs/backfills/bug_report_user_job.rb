# frozen_string_literal: true

module Backfills
  # Reports sent before their sender's account was created or confirmed
  class BugReportUserJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      BugReport.where(user_id: nil).find_each(&:save)
    end
  end
end
