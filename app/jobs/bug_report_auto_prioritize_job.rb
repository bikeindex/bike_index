# frozen_string_literal: true

class BugReportAutoPrioritizeJob < ApplicationJob
  # Subjects of emails Bike Index or mail servers send automatically, keyed by the tag they earn.
  # Internal notifications are the fixed subjects AdminMailer/AdminNotifier send to contact@bikeindex.org
  # (blocked stolen/marketplace notifications, no-admins and organization alerts), plus the
  # organization invitations and API error feedback the app sends it, and the forum's notices.
  AUTO_TAG_SUBJECT_REGEXES = {
    BugReport::INTERNAL_NOTIFICATION_TAG => /\A(stolen notification blocked!?|marketplace message blocked!?|.+ doesn.t have any admins!?|organization (wants|deleted) .+|join .+ ?on bike index|api bike creation error!|\[bike index forum\] .+)\z/i,
    # English, German, Dutch and French
    BugReport::AUTO_REPLY_TAG => /automatic reply|auto.?reply|out[- ]of[- ]office|automatische antwort|automatisch antwoord|r[ée]ponse automatique/i
  }.freeze
  # Recovery feedback's titles - people write in with the same words, so only the feedback panel's count
  RECOVERY_SUBJECT_REGEX = /\A((stolen )?bike recover(y|ed)!?|recovered bike)\z/i
  # Emails or domains whose messages are an organization's automated ticket system, tagged as
  # auto-replies whatever their subject. Configured
  # per-environment so no partner address lives in the repo; expandable without a code change.
  ORGANIZATION_AUTO_REPLY_SENDERS = ENV.fetch("BUG_REPORT_ORGANIZATION_AUTO_REPLY_SENDERS", "")
    .split(",").map { it.strip.downcase }.reject(&:blank?).freeze
  # Our own notifications - noise, or the feedback panel the mailbox tagged - shouldn't also be flagged spam
  NON_SPAM_TAGS = (BugReport::IGNORED_TAGS - [BugReport::SPAM_TAG] + [BugReport::FEEDBACK_TAG]).freeze

  def self.subject_tags(bug_report)
    subject = bug_report.subject.to_s.strip
    tags = AUTO_TAG_SUBJECT_REGEXES.select { |_tag, regex| subject.match?(regex) }.keys
    recovery = bug_report.tags.include?(BugReport::FEEDBACK_TAG) && subject.match?(RECOVERY_SUBJECT_REGEX)
    recovery ? tags | [BugReport::INTERNAL_NOTIFICATION_TAG] : tags
  end

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
    classified = self.class.subject_tags(bug_report) + sender_tags(bug_report)
    classified + spam_tags(bug_report, classified)
  end

  def spam_tags(bug_report, classified)
    return [] if (bug_report.tags + classified).intersect?(NON_SPAM_TAGS)
    return [] unless SpamEstimator::BugReport.estimate(bug_report) > SpamEstimator::BugReport::MARK_SPAM_PERCENT

    [BugReport::SPAM_TAG]
  end

  def sender_tags(bug_report)
    return [] unless organization_auto_reply_sender?(bug_report.email)

    [BugReport::AUTO_REPLY_TAG]
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
