class UpdateEmailDomainJob < ScheduledJob
  prepend ScheduledJobRecorder
  sidekiq_options retry: 1

  def self.frequency
    24.hours
  end

  def perform(domain_id = nil)
    return enqueue_workers if domain_id.blank?

    email_domain = EmailDomain.find(domain_id)
    email_domain.user_count = email_domain.calculated_users.count
    email_domain.data = {
      broader_domain_exists: broader_domain_exists(email_domain)
    }
    email_domain.save!
  end

  private

  def broader_domain_exists(email_domain)
    EmailDomain.find_matching_domain(email_domain.domain).id != email_domain.id
  end

  def enqueue_workers
    EmailDomain.pluck(:id).each { |id| self.class.perform_async(id) }
  end
end
