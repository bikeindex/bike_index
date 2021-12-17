class FetchProject529BikesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    23.5.hours
  end

  def perform(updated_since = nil, page = 1)
    updated_since ||= ExternalRegistryBike::Project529Bike.updated_since_date

    client = ExternalRegistryClient::Project529Client.new

    created_bikes = client.bikes(per_page: 100,
      page: page,
      updated_at: updated_since)

    return if created_bikes.empty?

    self.class.perform_async(updated_since, page + 1)
  end
end
