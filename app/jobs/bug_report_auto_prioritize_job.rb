# frozen_string_literal: true

class BugReportAutoPrioritizeJob < ApplicationJob
  # Subjects of emails Bike Index or mail servers send automatically, keyed by the tag they earn.
  # Internal notifications are the fixed subjects AdminMailer/AdminNotifier send to contact@bikeindex.org
  # (recovery feedback, blocked stolen/marketplace notifications, no-admins and organization alerts).
  AUTO_TAG_SUBJECT_REGEXES = {
    BugReport::INTERNAL_NOTIFICATION_TAG => /\A(bike recover(y|ed)|recovered bike|stolen notification blocked!?|marketplace message blocked!?|.+ doesn.t have any admins!?|organization (wants|deleted) .+)\z/i,
    BugReport::AUTO_REPLY_TAG => /automatic reply|auto.?reply|out[- ]of[- ]office/i
  }.freeze
  # Emails or domains whose messages are an organization's automated ticket system. Configured
  # per-environment so no partner address lives in the repo; expandable without a code change.
  ORGANIZATION_AUTO_REPLY_SENDERS = ENV.fetch("BUG_REPORT_ORGANIZATION_AUTO_REPLY_SENDERS", "")
    .split(",").map { it.strip.downcase }.reject(&:blank?).freeze
  # Reports already classified as internal/auto-reply noise shouldn't also be flagged spam
  NON_SPAM_IGNORED_TAGS = (BugReport::IGNORED_TAGS - [BugReport::SPAM_TAG]).freeze

  def perform(bug_report_id)
    bug_report = BugReport.find_by(id: bug_report_id)
    return unless bug_report

    bug_report.tags |= auto_tags(bug_report)
    # Only prioritize untriaged reports, so a manual status is never clobbered
    bug_report.status = calculated_status(bug_report) if bug_report.unprioritized?
    bug_report.save! if bug_report.changed?
  end

  private

  def auto_tags(bug_report)
    classified = subject_tags(bug_report) + sender_tags(bug_report)
    classified + spam_tags(bug_report, classified)
  end

  def spam_tags(bug_report, classified)
    return [] if (bug_report.tags + classified).intersect?(NON_SPAM_IGNORED_TAGS)
    return [] unless SpamEstimator::BugReport.estimate(bug_report) > SpamEstimator::BugReport::MARK_SPAM_PERCENT

    [BugReport::SPAM_TAG]
  end

  def subject_tags(bug_report)
    normalized_subject = bug_report.subject.to_s.strip
    AUTO_TAG_SUBJECT_REGEXES.select { |_tag, regex| normalized_subject.match?(regex) }.keys
  end

  def sender_tags(bug_report)
    return [] unless organization_auto_reply_sender?(bug_report.email)

    [BugReport::ORGANIZATION_AUTO_REPLY_TAG]
  end

  # A From header isn't required to contain "@" - without the guard, a domain-only sender
  # would match a configured domain and get auto-ignored
  def organization_auto_reply_sender?(email)
    email = email.to_s.downcase
    return false unless email.include?("@")

    domain = email.split("@").last
    ORGANIZATION_AUTO_REPLY_SENDERS.any? do |sender|
      next email == sender if sender.include?("@")

      domain == sender || domain.end_with?(".#{sender}")
    end
  end

  def calculated_status(bug_report)
    bug_report.ignored_tag? ? :ignored : :investigate_priority_low
  end
end
