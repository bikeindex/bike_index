class ScheduledBikeSerialMigrateWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  BIKE_COUNT = 10_000

  def self.frequency
    90.seconds
  end

  def perform(bike_id = nil)
    return enqueue_workers(BIKE_COUNT) if bike_id.blank?

    bike = Bike.unscoped.find_by_id(bike_id)
    return if bike.blank?
    bike.normalize_serial_number
    bike.update_columns(serial_number: bike.serial_number,
      serial_normalized: bike.serial_normalized,
      made_without_serial: bike.made_without_serial,
      serial_normalized_no_space: bike.serial_normalized_no_space)
  end

  def enqueue_workers(enqueue_limit)
    potential_bikes.limit(enqueue_limit).pluck(:id)
      .each { |i| ScheduledBikeSerialMigrateWorker.perform_async(i) }
  end

  def potential_bikes
    Bike.unscoped.where.not(serial_normalized: nil)
      .where(serial_normalized_no_space: nil)
  end
end
