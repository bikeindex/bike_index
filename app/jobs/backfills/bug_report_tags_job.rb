# frozen_string_literal: true

module Backfills
  # Organization ticket systems used to get their own auto_replies_organization tag, reports from
  # the feedback panel weren't tagged at all, and the subject rules have widened since
  class BugReportTagsJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    LEGACY_TAG = "auto_replies_organization"
    TRIAGE_TAG_PREFIXES = %w[ask_ area_].freeze

    def perform
      BugReport.with_tag(LEGACY_TAG).find_each do |bug_report|
        bug_report.update(tags: bug_report.tags - [LEGACY_TAG] + [BugReport::AUTO_REPLY_TAG])
      end
      BugReport.where("body LIKE ?", "%/admin/feedbacks/%").find_each do |bug_report|
        bug_report.update(tags: bug_report.tags | [BugReport::FEEDBACK_TAG]) if feedback_notification?(bug_report)
      end
      BugReport.with_tag(BugReport::INTERNAL_NOTIFICATION_TAG).find_each { untag_person_written_recovery(it) }
      BugReport.find_each { tag_by_subject(it) }
    end

    private

    # The mailbox checks the headers, but most inbound emails have been incinerated. The
    # notification's subject and Reply-To are the feedback's own, which a reply or forward's aren't
    def feedback_notification?(bug_report)
      feedback = Feedback.find_by(id: bug_report.feedback_id)
      feedback&.title == bug_report.subject &&
        EmailNormalizer.normalize(feedback.email) == bug_report.email
    end

    # Recovery subjects used to count as notifications whoever sent them
    def untag_person_written_recovery(bug_report)
      return if BugReportAutoPrioritizeJob.subject_tags(bug_report).include?(BugReport::INTERNAL_NOTIFICATION_TAG)
      return unless bug_report.subject.to_s.strip.match?(BugReportAutoPrioritizeJob::RECOVERY_SUBJECT_REGEX)

      tags = bug_report.tags - [BugReport::INTERNAL_NOTIFICATION_TAG]
      reprioritize = bug_report.ignored? && !tags.intersect?(BugReport::IGNORED_TAGS)
      bug_report.update(tags:, status: reprioritize ? :investigate_priority_low : bug_report.status)
    end

    # A triage classification is wrong once the subject marks a report automated
    def tag_by_subject(bug_report)
      tags = BugReportAutoPrioritizeJob.subject_tags(bug_report)
      return if (tags - bug_report.tags).none?

      triage_tags = bug_report.tags.select { |tag| tag.start_with?(*TRIAGE_TAG_PREFIXES) || tag == "bug" }
      bug_report.update(tags: bug_report.tags - triage_tags + tags,
        status: bug_report.resolved? ? :resolved : :ignored)
    end
  end
end
