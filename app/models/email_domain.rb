# frozen_string_literal: true

# == Schema Information
#
# Table name: email_domains
#
#  id                :bigint           not null, primary key
#  status_changed_at :datetime
#  data              :jsonb
#  deleted_at        :datetime
#  domain            :string
#  status            :integer          default("permitted")
#  user_count        :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  creator_id        :bigint
#
# Indexes
#
#  index_email_domains_on_creator_id  (creator_id)
#
class EmailDomain < ApplicationRecord
  include StatusHumanizable

  # setting ENV to 1 - but hopefully, when we're not as aggressively being attached, can lower/remove ENV
  EMAIL_MIN_COUNT = ENV.fetch("EMAIL_DOMAIN_BAN_USER_MIN_COUNT", 5).to_i
  STATUS_ENUM = {permitted: 0, ban_pending: 1, banned: 2}
  TLD_HAS_SUBDOMAIN = %w[.mx .uk .jp .in .nz .au .hk .us .za]

  acts_as_paranoid

  enum :status, STATUS_ENUM

  belongs_to :creator, class_name: "User"

  validates_presence_of :domain
  validates_uniqueness_of :domain
  validate :domain_is_expected_format
  validate :domain_is_not_contained_in_existing, on: :create

  before_save :set_calculated_attributes
  after_commit :enqueue_processing_worker, on: :create

  scope :ban_or_pending, -> { where(status: %i[ban_pending banned]) }
  scope :tld, -> { where("(data -> 'is_tld')::text = ?", "true") }
  scope :tld_matches_subdomains, -> { tld.where.not("domain ILIKE ?", "@%") }
  scope :subdomain, -> { where("(data -> 'is_tld')::text = ?", "false") }
  scope :with_bikes, -> { where("COALESCE((data -> 'bike_count')::integer, 0) > 0") }

  attr_accessor :skip_processing

  class << self
    def find_or_create_for(email_or_domain, skip_processing: false)
      domain = email_or_domain&.split("@")&.last&.strip
      return if domain.blank?
      domain = "@#{domain}" if email_or_domain.match?("@")

      find_matching_domain(domain) || create(domain:, skip_processing:)
    end

    def find_matching_domain(domain)
      tld = tld_for(domain)
      tld_match = where(domain: tld).first
      if tld_match.present?
        # For TLDs with subdomains, if a non-subdomain record is stored, return than
        if tld.count(".") > 1
          even_more_tld_match = where(domain: tld.gsub(/\A[^\.]*\./, "")).first

          return even_more_tld_match if even_more_tld_match.present?
        end
        return tld_match
      end

      matching_domain(tld).detect do |email_domain|
        domain.match?(email_domain.domain)
      end
    end

    def no_valid_organization_roles?(domain)
      org_ids = OrganizationRole.unscoped.where("invited_email ILIKE ?", "%#{domain}").pluck(:organization_id)
      Organization.approved.where(id: org_ids).none?
    end

    def status_humanized(str)
      str.humanize
    end

    def tld_for(email_or_domain)
      domain = email_or_domain&.split("@")&.last&.strip
      return domain if domain.split(".").count == 1

      multi_subdomain = TLD_HAS_SUBDOMAIN.any? { domain.end_with?(_1) }
      return domain if multi_subdomain && domain.split(".").count < 3

      start_subdomain = multi_subdomain ? -3 : -2
      domain.split(".")[start_subdomain..].join(".")
    end

    def matching_domain(domain)
      where("domain ILIKE ?", "%#{domain.tr("@", "")}").order(Arel.sql("length(domain) ASC"))
    end
  end

  def ban_or_pending?
    banned? || ban_pending?
  end

  def tld
    data&.dig("tld")
  end

  def tld?
    data&.dig("is_tld")
  end

  def tld_matches_subdomains?
    tld? && !domain.start_with?("@")
  end

  def bike_count
    data&.dig("bike_count")&.to_i || 0
  end

  def notification_count
    data&.dig("notification_count")&.to_i || 0
  end

  def broader_domain_exists?
    InputNormalizer.boolean(data&.dig("broader_domain_exists"))
  end

  # Only check for ban_blockers if the domain is not banned
  def auto_bannable?
    return false if has_ban_blockers?

    spam_score < 4
  end

  def has_ban_blockers?
    b_count = calculated_bikes.count
    u_count = calculated_users.count
    return true if u_count < EMAIL_MIN_COUNT

    # Ensure that domains that registered bikes before the creation of EmailDomains aren't blocked
    return true if b_count > 0 && (b_count + 1) > (u_count * 0.1)

    # Ensure domains for organizations aren't blocked
    return true if calculated_users.with_organization_roles.count > 2

    # Ensure there aren't permitted subdomains
    calculated_subdomains.permitted.count > 0
  end

  def spam_score
    return 10 if data.blank? # Don't judge unless data is present

    # 2 points for valid domain (and 2 more for valid subdomain, or being the TLD)
    base_score = data.slice("domain_resolves", "tld_resolves").count { |_k, v| v } * 2
    # SendGrid validation appears to be worse than useless, so skipping for now
    return base_score unless data["sendgrid_validations"].present?

    validation_scores = data["sendgrid_validations"].values.map { |result| result["score"].to_f }
    (base_score + validation_scores.max).round(1)
  end

  # IDK if this is really necessary, but it makes the matching class method easier
  def at_domain
    domain.match?("@") ? domain : "@#{domain}"
  end

  def status_humanized
    self.class.status_humanized(status)
  end

  def domain_is_expected_format
    self.domain = domain.strip

    errors.add(:domain, "Must include a .") unless domain.match?(/\./)
  end

  def domain_is_not_contained_in_existing
    broader_domain = self.class.find_matching_domain(domain)
    return if broader_domain.blank?
    # Allow creating without @, if an @domain exists
    return if broader_domain.domain == "@#{domain}"

    errors.add(:domain, "already exists: '#{broader_domain.domain}'")
  end

  def calculated_users
    User.matching_domain(domain)
  end

  def calculated_bikes
    Bike.matching_domain(domain)
  end

  def calculated_notifications
    Notification.where("message_channel_target ILIKE ?", "%#{domain}")
  end

  def calculated_subdomains
    return self.class.none unless tld?

    self.class.subdomain.matching_domain(domain)
  end

  def no_auto_assign_status?
    data["no_auto_assign_status"]&.to_s == "true"
  end

  def status_changed_after_create?
    (status_changed_at - created_at).abs >= 60.seconds
  end

  def process!
    return if skip_processing
    UpdateEmailDomainJob.new.perform(id, self)
    reload
  end

  def unprocessed?
    user_count.nil?
  end

  def enqueue_processing_worker
    UpdateEmailDomainJob.perform_async(id)
  end

  private

  def set_calculated_attributes
    self.data ||= {}
    self.data["tld"] = self.class.tld_for(domain)
    self.data["is_tld"] = data["tld"].length >= domain&.tr("@", "")&.length

    if status_changed?
      self.status_changed_at = Time.current
    else
      self.status_changed_at ||= created_at || Time.current
    end
  end
end
