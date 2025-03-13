class UpdateEmailDomainJob < ScheduledJob
  prepend ScheduledJobRecorder

  CREATE_TLD_SUBDOMAIN_COUNT = 3

  sidekiq_options retry: 1

  def self.frequency
    24.hours
  end

  def self.auto_pending_ban?(email_domain)
    if email_domain.bike_count.present? && email_domain.bike_count > 0
      # Ensure that domains that registered bikes before the creation of EmailDomains aren't blocked
      return false if (email_domain.bike_count + 1) > (email_domain.user_count * 0.1)
    end
    # Ensure domains for organizations aren't blocked
    return false if email_domain.calculated_users.with_organization_roles.count > 2

    email_domain.data.slice("domain_resolves", "tld_resolves").values.map(&:to_s) != %w[true true]
  end

  def perform(domain_id = nil, email_domain = nil)
    return enqueue_workers if domain_id.blank?

    email_domain ||= EmailDomain.find(domain_id)
    email_domain.user_count = email_domain.calculated_users.count
    email_domain.data.merge!(calculated_data(email_domain).as_json)

    unless email_domain.no_auto_assign_status? || email_domain.ban_or_pending?
      email_domain.status = "ban_pending" if self.class.auto_pending_ban?(email_domain)
    end

    email_domain.save!
    EmailDomain.find_or_create_for(email_domain.tld) if create_tld_for_subdomains?(email_domain)
    email_domain
  end

  private

  def enqueue_workers
    EmailDomain.pluck(:id).each { |id| self.class.perform_async(id) }
  end

  def calculated_data(email_domain)
    {
      broader_domain_exists: EmailDomain.find_matching_domain(email_domain.domain).id != email_domain.id,
      domain_resolves: domain_resolves?(email_domain.domain),
      tld_resolves: domain_resolves?(email_domain.tld),
      bike_count: email_domain.calculated_bikes.count,
      subdomain_count: email_domain.calculated_subdomains.count
    }
  end

  def domain_resolves?(domain)
    conn = Faraday.new do |faraday|
      faraday.use FaradayMiddleware::FollowRedirects, limit: 15
      faraday.adapter Faraday.default_adapter
      # Set reasonable timeouts to avoid hanging
      faraday.options.timeout = 5        # 5 seconds for open/read timeout
      faraday.options.open_timeout = 2   # 2 seconds for connection timeout
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
    return false if email_domain.tld? || email_domain.permitted?

    tld = email_domain.tld
    return false if EmailDomain.tld_matches_subdomains.matching_domain(tld).any?

    return false if EmailDomain.matching_domain(tld).count < CREATE_TLD_SUBDOMAIN_COUNT

    true
  end
end
