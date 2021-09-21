class FetchProject529BikesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    23.5.hours
  end

  def perform(page = 1)
    client = ExternalRegistryClient::Project529Client.new

    created_bikes = client.bikes(per_page: 100,
      page: page,
      updated_at: ExternalRegistryBike::Project529Bike.fetch_from_date)

    return if created_bikes.empty?

    self.class.perform_async(page + 1)
  end
end
