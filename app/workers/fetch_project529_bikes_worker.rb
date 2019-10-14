class FetchProject529BikesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.hours
  end

  def perform(page = 1)
    client = ExternalRegistryClient::Project529Client.new
    results = client.bikes(updated_at: from_start_date, per_page: 20, page: page)
    return if results.empty?

    self.class.perform_async(page + 1)
  end

  # historical or delta query, depending on the pre-existence of 529 records.
  # bounded to 20 days because of performance constraints on the api.
  def from_start_date
    if ExternalRegistryBike::Project529Bike.count.zero?
      Time.current - 20.day
    else
      Time.current - 1.day
    end
  end
end
