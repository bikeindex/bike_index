# frozen_string_literal: true

class UpdateEmailDomainJob < ScheduledJob
  prepend ScheduledJobRecorder

  CREATE_TLD_SUBDOMAIN_COUNT = 3
  SENDGRID_VALIDATION_KEY = ENV["SENDGRID_EMAIL_VALIDATION_KEY"].freeze
  VALIDATE_WITH_SENDGRID = EmailDomain::VERIFICATION_ENABLED && SENDGRID_VALIDATION_KEY.present?
  SENDGRID_VALIDATION_URL = "https://api.sendgrid.com/v3/validations/email"

  class << self
    def frequency
      24.hours
    end

    def auto_pending_ban?(email_domain)
      return false if email_domain.has_ban_blockers?

      email_domain.data.slice("domain_resolves", "tld_resolves").values.map(&:to_s) != %w[true true]
    end
  end

  def perform(domain_id = nil, email_domain = nil, validate_sendgrid_email_id = nil)
    return enqueue_workers if domain_id.blank?

    email_domain ||= EmailDomain.find(domain_id)
    email_domain.user_count = email_domain.calculated_users.count
    email_domain.data.merge!(calculated_data(email_domain).as_json)
    if validate_with_sendgrid?(email_domain) || validate_sendgrid_email_id.present?
      email_domain.data["sendgrid_validations"] ||= {}
      # Grab the second email that was created (if it exists)
      email = if validate_sendgrid_email_id.present?
        User.unscoped.find(validate_sendgrid_email_id).email
      else
        email_domain.calculated_users.order(:id).limit(2).pluck(:email).last
      end
      email_domain.data["sendgrid_validations"][email] = sendgrid_validation(email)
    end

    unless email_domain.no_auto_assign_status? || email_domain.banned?
      email_domain.status = email_domain.auto_bannable? ? "provisional_ban" : "permitted"
    end

    email_domain.save!
    if create_tld_for_subdomains?(email_domain)
      EmailDomain.find_or_create_for(email_domain.tld)
    elsif email_domain.banned? && email_domain.user_count > 0
      email_domain.calculated_subdomains.each(&:destroy)
      email_domain.calculated_users.find_each { |user| user.really_destroy! }
    elsif email_domain.provisional_ban? && email_domain.tld_matches_subdomains?
      email_domain.calculated_subdomains.where.not(status: email_domain.status).pluck(:id)
        .each { UpdateEmailDomainJob.perform_async(_1) }
    end
    email_domain
  end

  private

  def enqueue_workers
    EmailDomain.pluck(:id).each { |id| self.class.perform_async(id) }
  end

  def calculated_data(email_domain)
    broader_domain_exists = if email_domain.ignored?
      false
    else
      EmailDomain.find_matching_domain(email_domain.domain)&.id != email_domain.id
    end
    {
      broader_domain_exists:,
      domain_resolves: domain_resolves?(email_domain.domain),
      tld_resolves: domain_resolves?(email_domain.tld),
      bike_count: email_domain.calculated_bikes.count,
      bike_count_pos: email_domain.calculated_bikes.any_pos.count,
      user_count_donated: email_domain.calculated_users.donated.count,
      subdomain_count: email_domain.calculated_subdomains.count,
      b_param_count: email_domain.calculated_b_params.count,
      notification_count: email_domain.calculated_notifications.count,
      spam_score: email_domain.spam_score # just stored so we can sort by it
    }
  end

  def domain_resolves?(domain)
    return false if EmailDomain.invalid_domain?(domain)

    conn = Faraday.new do |faraday|
      faraday.use FaradayMiddleware::FollowRedirects, limit: 15
      faraday.adapter Faraday.default_adapter
      # Set reasonable timeouts to avoid hanging
      faraday.options.timeout = 5 # 5 seconds for open/read timeout
      faraday.options.open_timeout = 2 # 2 seconds for connection timeout
    end

    begin
      response = conn.head("http://#{domain.tr("@", "")}")
      response.success?
    rescue Faraday::Error
      # Catch connection errors, SSL errors, timeouts, redirects exceeding limit, etc.
      false
    rescue URI::InvalidURIError
      # Handle invalid URLs
      false
    end
  end

  def create_tld_for_subdomains?(email_domain)
    return false if email_domain.tld?

    EmailDomain.broadest_matching_domains(email_domain.domain).count > CREATE_TLD_SUBDOMAIN_COUNT
  end

  def validate_with_sendgrid?(email_domain)
    return false if !VALIDATE_WITH_SENDGRID || email_domain.ban_blockers.any?

    email_domain.data["sendgrid_validations"].blank?
  end

  def sendgrid_validation(email)
    result = Faraday.new(url: SENDGRID_VALIDATION_URL).post do |conn|
      conn.headers["Content-Type"] = "application/json"
      conn.headers["Authorization"] = "Bearer #{SENDGRID_VALIDATION_KEY}"
      conn.body = {email:, source: "EmailDomain"}.to_json
    end

    JSON.parse(result.body)["result"]
  end
end
