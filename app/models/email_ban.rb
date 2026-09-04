# == Schema Information
#
# Table name: email_bans
# Database name: primary
#
#  id            :bigint           not null, primary key
#  end_at        :datetime
#  reason        :integer
#  start_at      :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_email_id :bigint
#  user_id       :bigint
#
# Indexes
#
#  index_email_bans_on_user_email_id  (user_email_id)
#  index_email_bans_on_user_id        (user_id)
#
class EmailBan < ApplicationRecord
  include ActivePeriodable

  BLOCK_DUPLICATE_PERIOD = 1.day
  PRE_PERIOD_DUPLICATE_LIMIT = 2
  PERMITTED_DUPLICATE_DOMAINS = %w[bikeindex.org bikehub.com].freeze
  REASON_ENUM = {email_domain: 0, email_duplicate: 1, delivery_failure: 2, honeypot: 3}.freeze

  enum :reason, REASON_ENUM

  belongs_to :user
  belongs_to :user_email

  validates_presence_of :reason, :user
  validate :is_not_duplicate_ban

  before_validation :set_calculated_attributes

  # A ban on an additional address leaves the account's own address deliverable
  scope :banning_account_email, lambda {
    left_joins(:user_email).joins(:user)
      .where("email_bans.user_email_id IS NULL OR user_emails.email = users.email")
  }

  class << self
    def ban?(user, user_email: nil, is_new_email_address: false)
      return false if user.blank?

      user_email ||= user.user_emails.friendly_find(user.email)
      return true if is_new_email_address && banned_new_email_address?(user, user_email)

      matching_bans(user, user_email).any?
    end

    def reason_humanized(str)
      return nil unless str.present?

      str.humanize.gsub(/email/i, "").strip.downcase
    end

    private

    # Asks whether the address should exist, not whether it accepts mail - and
    # REPLACE(email) has no index, so it can't run on every send
    def banned_new_email_address?(user, user_email)
      # Only the account's own address condemns the account - an additional one is just an address
      additional = user_email if user_email&.email != user.email
      email = additional&.email || user.email

      if EmailDomain::VERIFICATION_ENABLED
        email_domain = EmailDomain.find_or_create_for(email, skip_processing: true)

        process_email_domain_if_required(email_domain)

        if email_domain.banned?
          # Don't suffer a witch to live
          additional.present? ? create(reason: :email_domain, user:, user_email: additional) : user.really_destroy!
          return true
        end
      end

      create(reason: :email_domain, user:, user_email: additional) if email_domain&.provisional_ban?
      create(reason: :email_duplicate, user:, user_email: additional) if email_duplicate?(email)
      false
    end

    # A ban with no user_email covers every address the user has
    def matching_bans(user, user_email)
      user.email_bans_active.where(user_email_id: [nil, user_email&.id])
    end

    def email_duplicate?(email)
      return false if PERMITTED_DUPLICATE_DOMAINS.include?(email.split("@").last)

      email_period_duplicate?(email) || email_plus_duplicate?(email)
    end

    def email_period_duplicate?(email)
      matches = User.where("REPLACE(email, '.', '') = ?", email.tr(".", ""))
        .where.not(email: email)

      return true if matches.where("created_at > ?", Time.current - BLOCK_DUPLICATE_PERIOD).any?

      matches.count > PRE_PERIOD_DUPLICATE_LIMIT
    end

    def email_plus_duplicate?(email)
      return false unless email.match?(/\+.*@/)

      matches = email_plus_duplicate_matches(email)

      return true if matches.where("created_at > ?", Time.current - BLOCK_DUPLICATE_PERIOD).any?

      matches.count > PRE_PERIOD_DUPLICATE_LIMIT
    end

    def email_plus_duplicate_matches(email)
      email_start, email_end = email.split("@")
      email_start.gsub!(/\+.*/, "")

      User.where("email ~ ?", "^#{email_start}(\\+.*)?@#{email_end}").where.not(email:)
    end

    def process_email_domain_if_required(email_domain)
      # Inline process new email_domains
      return email_domain.process! if email_domain.unprocessed?

      # enqueue async processing for email domains
      email_domain.enqueue_processing_worker if email_domain.should_re_process?
    end
  end

  def email
    user_email&.email || user&.email
  end

  def email_domain
    return nil if email.blank?

    EmailDomain.find_or_create_for(email, skip_processing: true)
  end

  def reason_humanized
    self.class.reason_humanized(reason)
  end

  private

  def set_calculated_attributes
    self.start_at ||= Time.current
    # With one address on file, a ban on it is a ban on the user - but only at create,
    # since removing an address later shouldn't widen the ban that named it
    self.user_email_id = nil if new_record? && !multiple_user_emails?
  end

  def is_not_duplicate_ban
    matching_previous_ban = self.class.where(user_id:, reason:, user_email_id:).period_active_at(start_at)
      .where.not(id:)
    matching_previous_ban = matching_previous_ban.where("id < ?", id) if id.present?
    return if matching_previous_ban.none?

    errors.add(:user_id, "there is already an active email_ban for the same reason for that user")
  end

  def multiple_user_emails?
    user.present? && user.user_emails.size > 1
  end
end
