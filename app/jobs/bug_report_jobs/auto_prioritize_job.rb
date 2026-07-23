# frozen_string_literal: true

module BugReportJobs
  class AutoPrioritizeJob < ApplicationJob
    def perform(bug_report_id)
      bug_report = BugReport.find_by(id: bug_report_id)
      # Only auto-prioritize untriaged reports, so a manual status is never clobbered
      return unless bug_report&.unprioritized?

      bug_report.update!(status: :investigate_priority_low)
    end
  end
end
