class ScheduledBikeSerialMigrateWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  BIKE_COUNT = (ENV["BIKE_COUNT"].presence || 100).to_i

  def self.frequency
    90.seconds
  end

  def perform(bike_id = nil)
    return enqueue_workers(BIKE_COUNT) if bike_id.blank?

  end

  def enqueue_workers(enqueue_limit)
    potential_bikes.limit(enqueue_limit).pluck(:id)
      .each { |i| ScheduledBikeSerialMigrateWorker.perform_async(i) }
  end

  def potential_bikes
  end
end
