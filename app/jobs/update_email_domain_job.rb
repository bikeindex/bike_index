class UpdateEmailDomainJob < ScheduledJob
  prepend ScheduledJobRecorder
  sidekiq_options retry: 1

  def self.frequency
    24.hours
  end

  def perform(domain_id = nil)
    return enqueue_workers if domain_id.blank?


  end

  def enqueue_workers
    EmailDomain.pluck(:id).each { |id| self.class.perform_async(id) }
  end
end
