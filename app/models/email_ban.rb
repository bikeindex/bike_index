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

  validates_presence_of :reason
  validate :is_not_duplicate_ban

  before_validation :set_calculated_attributes

  class << self
    def ban?(user, user_email: nil, destroy_for_banned_domain: false)
      return false if user.blank?

      if EmailDomain::VERIFICATION_ENABLED
        email_domain = EmailDomain.find_or_create_for(user.email, skip_processing: true)

        process_email_domain_if_required(email_domain)

        if email_domain.banned?
          # Don't suffer a witch to live
          user.really_destroy! if destroy_for_banned_domain
          return true
        end
      end

      # Create a email ban if we should
      create(reason: :email_domain, user:) if email_domain&.provisional_ban?
      create(reason: :email_duplicate, user:) if email_duplicate?(user.email)
      # match existing bans
      matching_bans(user, user_email).any?
    end

    def create_delivery_failure(user:, user_email: nil)
      return if user.blank?

      create(reason: :delivery_failure, user:, user_email:)
    end

    # An email getting through means the address works again - but it says nothing
    # about the bans for the other reasons
    def resolve_delivery_failure(user:, user_email: nil)
      return if user.blank?

      matching_bans(user, user_email).delivery_failure.each { it.update(end_at: Time.current) }
    end

    def reason_humanized(str)
      return nil unless str.present?

      str.humanize.gsub(/email/i, "").strip.downcase
    end

    private

    def matching_bans(user, user_email)
      period_active.where(user:, user_email_id: [nil, matching_user_email_id(user, user_email)])
    end

    # A ban without a user_email covers every address the user has; without an
    # explicit address, the question being asked is about their primary one
    def matching_user_email_id(user, user_email)
      (user_email || user.user_emails.friendly_find(user.email))&.id
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

  def set_calculated_attributes
    self.start_at ||= Time.current
    self.user_email_id = nil unless multiple_user_emails?
  end

  def is_not_duplicate_ban
    matching_previous_ban = self.class.where(user_id:, reason:, user_email_id:).period_active_at(start_at)
      .where.not(id:)
    matching_previous_ban = matching_previous_ban.where("id < ?", id) if id.present?
    return if matching_previous_ban.none?

    errors.add(:user_id, "there is already an active email_ban for the same reason for that user")
  end

  private

  # With one address on file, a ban on it is a ban on the user
  def multiple_user_emails?
    user.present? && user.user_emails.count > 1
  end
end
