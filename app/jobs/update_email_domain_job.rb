class UpdateEmailDomainJob < ScheduledJob
  prepend ScheduledJobRecorder
  sidekiq_options retry: 1

  def self.frequency
    24.hours
  end

  def perform(domain_id = nil, email_domain = nil)
    return enqueue_workers if domain_id.blank?

    email_domain ||= EmailDomain.find(domain_id)
    email_domain.user_count = email_domain.calculated_users.count
    email_domain.data.merge!(calculated_data(email_domain).as_json)

    unless email_domain.no_auto_assign_status? || email_domain.ban_or_pending?
      email_domain.status = "ban_pending" if auto_pending_ban?(email_domain.data)
    end

    email_domain.save!
  end

  private

  def enqueue_workers
    EmailDomain.pluck(:id).each { |id| self.class.perform_async(id) }
  end

  def auto_pending_ban?(data)
    data.slice("domain_resolves", "tld_resolves").values.map(&:to_s) != %w[true true]
  end

  def calculated_data(email_domain)
    {
      broader_domain_exists: EmailDomain.find_matching_domain(email_domain.domain).id != email_domain.id,
      domain_resolves: domain_resolves?(email_domain.domain),
      tld_resolves: domain_resolves?(email_domain.tld),
      bike_count: Bike.matching_domain(email_domain.domain).count
    }
  end

  def domain_resolves?(domain)
    conn = Faraday.new do |faraday|
      faraday.use FaradayMiddleware::FollowRedirects, limit: 4
      faraday.adapter Faraday.default_adapter
      # Set reasonable timeouts to avoid hanging
      faraday.options.timeout = 5        # 5 seconds for open/read timeout
      faraday.options.open_timeout = 2   # 2 seconds for connection timeout
    end

    begin
      response = conn.head("https://#{domain.tr("@", "")}")
      response.success?
    rescue Faraday::Error
      # Catch connection errors, SSL errors, timeouts, redirects exceeding limit, etc.
      false
    rescue URI::InvalidURIError
      # Handle invalid URLs
      false
    end
  end
end
