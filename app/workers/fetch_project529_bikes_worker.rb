class FetchProject529BikesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.hours
  end

  def perform(page = 1)
    results = ExternalRegistryClient::Project529Client.bikes(updated_at: Time.current - 1.day, per_page: 40, page: page)
    return if results.empty?
    self.class.perform_async(page + 1)
  end
end
