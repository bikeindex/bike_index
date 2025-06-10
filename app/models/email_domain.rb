# frozen_string_literal: true

# == Schema Information
#
# Table name: email_domains
#
#  id                :bigint           not null, primary key
#  data              :jsonb
#  deleted_at        :datetime
#  domain            :string
#  status            :integer          default("permitted")
#  status_changed_at :datetime
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

  INVALID_REGEX = /[\/\\\(\)\[\]=\s!"']/
  INVALID_DOMAIN = "(invalid).domain"
  EMAIL_MIN_COUNT = ENV.fetch("EMAIL_DOMAIN_BAN_USER_MIN_COUNT", 3).to_i
  STATUS_ENUM = {permitted: 0, provisional_ban: 1, banned: 2, ignored: 3}.freeze
  TLD_HAS_SUBDOMAIN = %w[.au .hk .il .in .jp .mx .nz .tw .uk .us .za].freeze
  SPAM_SCORE_AUTO_BAN = 5
  # We don't verify with EmailDomains in most tests because it slows things down.
  # This also includes an env to turn if off in case things block up
  VERIFICATION_ENABLED = (!Rails.env.test? && ENV["SKIP_EMAIL_DOMAIN_VERIFICATION"] != "true").freeze
  MEMOIZE_INVALID = ENV["SKIP_MEMOIZE_STATIC_MODEL_RECORDS"].blank? # enable skipping for testing
  # always reprocess once a month
  ALWAYS_RE_PROCESS_DELAY = 1.month.to_i.freeze
  RE_PROCESS_DELAY = 1.hour

  acts_as_paranoid

  enum :status, STATUS_ENUM

  belongs_to :creator, class_name: "User"

  validates_presence_of :domain
  validates_uniqueness_of :domain
  validate :domain_is_expected_format
  validate :domain_does_not_match_existing, on: :create

  before_validation :set_calculated_attributes
  after_commit :enqueue_processing_worker, on: :create

  scope :ban_or_provisional, -> { where(status: %i[provisional_ban banned]) }
  scope :tld, -> { where("(data -> 'is_tld')::text = ?", "true") }
  scope :tld_matches_subdomains, -> { tld.where.not("domain ILIKE ?", "@%") }
  scope :subdomain, -> { where("(data -> 'is_tld')::text = ?", "false") }
  scope :with_bikes, -> { where("COALESCE((data -> 'bike_count')::integer, 0) > 0") }
  scope :no_auto_assign_status, -> { where("(data -> 'no_auto_assign_status')::text =?", "true") }

  attr_accessor :skip_processing

  class << self
    def find_or_create_for(email_or_domain, skip_processing: false)
      domain = email_or_domain&.split("@")&.last&.strip
      return if domain.blank?
      domain = "@#{domain}" if email_or_domain.match?("@")

      find_matching_domain(domain) || create(domain:, skip_processing:)
    end

    def find_matching_domain(domain)
      return invalid_domain_record if invalid_domain?(domain)

      find_by(domain:) || find_by(domain: domain.tr("@", ""))
    end

    def invalid_domain_record
      return @invalid_domain_record if MEMOIZE_INVALID && defined?(@invalid_domain_record)

      @invalid_domain_record = where(domain: INVALID_DOMAIN, status: "banned").first_or_create
    end

    def invalid_domain?(domain)
      domain =~ INVALID_REGEX
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
      return INVALID_DOMAIN if invalid_domain?(domain)
      return domain if domain.split(".").count == 1

      multi_subdomain = TLD_HAS_SUBDOMAIN.any? { domain.end_with?(_1) }
      return domain if multi_subdomain && domain.split(".").count < 3

      start_subdomain = multi_subdomain ? -3 : -2
      domain.split(".")[start_subdomain..].join(".")
    end

    def broadest_matching_domains(domain)
      search_domain = tld_for(domain)
      not_ignored.where("domain ILIKE ?", "%#{search_domain}").order(Arel.sql("length(domain) ASC"))
    end
  end

  def ban_or_provisional?
    banned? || provisional_ban?
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

  def b_param_count
    data&.dig("b_param_count")&.to_i || 0
  end

  def broader_domain_exists?
    InputNormalizer.boolean(data&.dig("broader_domain_exists"))
  end

  # Only check for ban_blockers if the domain is not banned
  def auto_bannable?
    return false if ban_blockers.any?

    spam_score > SPAM_SCORE_AUTO_BAN
  end

  def ban_blockers
    b_blockers = []
    b_blockers << "below_email_count" if below_email_count_blocker?
    b_blockers << "bike_count" if bike_count_blocker?
    b_blockers << "organization_role" if organization_role_blocker?
    b_blockers << "permitted_subdomains" if calculated_subdomains.permitted.count > 0
    b_blockers
  end

  # If users don't confirm, they get deleted - so check notifications count instead of users
  def below_email_count_blocker?
    (notification_count / 2) < EMAIL_MIN_COUNT
  end

  # Ensure that domains that registered bikes before the creation of EmailDomains aren't blocked
  def bike_count_blocker?
    calculated_bike_count > 0 && (calculated_bike_count + 1) > (calculated_user_count * 0.1)
  end

  # Ensure domains for organizations aren't blocked
  def organization_role_blocker?
    calculated_users.with_organization_roles.count > 2
  end

  def spam_score
    return 1 if data.blank? # Don't judge unless data is present

    s_score = (10 - spam_score_domain_resolution - spam_score_our_records - spam_score_sendgrid_validations)
      .clamp(1, 10)
    (s_score == 1) ? score_zero_if_allowed : s_score
  end

  def spam_score_domain_resolution
    # 2 points for valid domain (and 2 more for valid subdomain, or being the TLD)
    data.slice("domain_resolves", "tld_resolves").count { |_k, v| v } * 1.5
  end

  def spam_score_our_records
    uc = user_count || 0 # protect against nil
    score = 0
    score += 1 if bike_count > 0
    score += 3 if bike_count > (uc / 2)
    score += 3 if (data["user_count_donated"]&.to_i || 0) > 1
    score += 3 if (data["bike_count_pos"]&.to_i || 0) > 0
    # if domain has a high notification count, it often means they have a lot of unconfirmed users
    score -= 1 if (bike_count + uc) < notification_count
    score.clamp(0, 9)
  end

  # SendGrid validation appears to be pretty much useless. Using just decimal for now, which has no effect
  def spam_score_sendgrid_validations
    return 0 unless data["sendgrid_validations"].present?

    data["sendgrid_validations"].values.map { |result| result&.dig("score")&.to_f }.max&.round(1) || 0
  end

  def status_humanized
    self.class.status_humanized(status)
  end

  def calculated_users
    User.confirmed.matching_domain(domain)
  end

  def calculated_bikes
    Bike.matching_domain(domain)
  end

  def calculated_b_params
    BParam.matching_domain(domain)
  end

  def calculated_notifications
    Notification.where("message_channel_target ILIKE ?", "%#{domain}")
  end

  def calculated_subdomains
    return self.class.none unless tld?

    self.class.subdomain.where.not(id:).broadest_matching_domains(domain)
  end

  def invalid_domain?
    domain == INVALID_DOMAIN
  end

  def no_auto_assign_status?
    data["no_auto_assign_status"]&.to_s == "true"
  end

  def status_changed_after_create?
    (status_changed_at - created_at).abs >= 60.seconds
  end

  def unprocessed?
    user_count.nil?
  end

  def should_re_process?
    return false if %w[banned ignored].include?(status)
    return true if data&.dig("spam_score").blank? || (data["notification_count"]&.to_i || 0) < 20 ||
      updated_at < (Time.current - ALWAYS_RE_PROCESS_DELAY)

    # recalculate very likely spam or very unlikely spam
    sscore = data["spam_score"].to_i
    return true if sscore > 3 && sscore < 7
    return false if sscore == 0 # leave these for a month

    updated_at < (Time.current - RE_PROCESS_DELAY)
  end

  def processed?
    !unprocessed?
  end

  def process!
    UpdateEmailDomainJob.new.perform(id, self)
    reload
  end

  def enqueue_processing_worker
    return if skip_processing

    UpdateEmailDomainJob.perform_async(id)
  end

  private

  def score_zero_if_allowed
    ((data["bike_count_pos"]&.to_i&.> 1) && user_count > 5) ? 0 : 1
  end

  def domain_is_expected_format
    self.domain = domain.strip

    errors.add(:domain, "Must include a .") unless domain.match?(/\./)
  end

  def domain_does_not_match_existing
    return if invalid_domain?

    existing_domain = self.class.find_matching_domain(domain)
    return if existing_domain.blank?
    # Allow creating without @, if an @domain exists
    return if existing_domain.domain == "@#{domain}"

    errors.add(:domain, "already exists: '#{existing_domain.domain}'")
  end

  # Used for calculations in blockers
  def calculated_bike_count
    @calculated_bike_count ||= calculated_bikes.count
  end

  # Used for calculations in blockers
  def calculated_user_count
    @calculated_user_count ||= calculated_users.count
  end

  def set_calculated_attributes
    self.data ||= {}
    self.data["tld"] = self.class.tld_for(domain)
    self.data["is_tld"] = data["tld"].length >= domain&.tr("@", "")&.length

    if !no_auto_assign_status? && !ban_or_provisional?
      broader_status = broader_domain_bannable_status

      self.status = broader_status if broader_status.present?
    end

    if status_changed?
      self.status_changed_at = Time.current
    else
      self.status_changed_at ||= created_at || Time.current
    end
  end

  def broader_domain_bannable_status
    statuses = broader_domains.ban_or_provisional.pluck(:status).uniq
    return nil if statuses.none?

    statuses.include?("banned") ? "banned" : statuses.first
  end

  def broader_domains
    self.class.broadest_matching_domains(domain).where.not(id:)
      .where(Arel.sql("length(domain) < ?", domain.length))
  end
end
