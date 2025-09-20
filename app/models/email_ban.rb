# == Schema Information
#
# Table name: email_bans
#
#  id         :bigint           not null, primary key
#  end_at     :datetime
#  reason     :integer
#  start_at   :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_email_bans_on_user_id  (user_id)
#
class EmailBan < ApplicationRecord
  include ActivePeriodable

  BLOCK_DUPLICATE_PERIOD = 1.day
  PRE_PERIOD_DUPLICATE_LIMIT = 2
  PERMITTED_DUPLICATE_DOMAINS = %w[bikeindex.org].freeze
  REASON_ENUM = {email_domain: 0, email_duplicate: 1, delivery_failure: 2}.freeze

  belongs_to :user

  enum :reason, REASON_ENUM

  validates :reason, presence: true
  validate :is_not_duplicate_ban

  before_validation :set_calculated_attributes
  class << self
    def ban?(user)
      # Don't suffer a witch to live
      if EmailDomain::VERIFICATION_ENABLED
        email_domain = EmailDomain.find_or_create_for(user.email, skip_processing: true)

        process_email_domain_if_required(email_domain)

        if email_domain.banned?
          user.really_destroy!
          return true
        end
      end

      # Create a email ban if we should
      create(reason: :email_domain, user:) if email_domain&.provisional_ban?
      create(reason: :email_duplicate, user:) if email_duplicate?(user.email)
      # match existing bans
      period_started.where(user:).any?
    end

    def reason_humanized(str)
      return nil unless str.present?

      str.humanize.gsub(/email/i, "").strip.downcase
    end

    private

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
    user&.email
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
  end

  def is_not_duplicate_ban
    matching_previous_ban = self.class.where(user_id:, reason:).period_active_at(start_at)
      .where.not(id:)
    matching_previous_ban = matching_previous_ban.where("id < ?", id) if id.present?
    return if matching_previous_ban.none?

    errors.add(:user_id, "there is already an active email_ban for the same reason for that user")
  end
end
