class ScheduledBikeSerialMigrateWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  BIKE_COUNT = (ENV["BIKE_COUNT"].presence || 100).to_i

  def self.frequency
    90.seconds
  end

  def perform(bike_id = nil)
    return enqueue_workers(BIKE_COUNT) if bike_id.blank?

    bike = Bike.unscoped.find_by_id(bike_id)
    return if bike.blank?
    serial_number = SerialNormalizer.unknown_and_absent_corrected(bike.serial_number)
    serial_normalized = SerialNormalizer.new(serial: serial_number).normalized
    serial_normalized_no_space = serial_normalized.gsub(/\s/, "")
    bike.update_columns(serial_number: serial_number,
      serial_normalized: serial_normalized,
      serial_normalized_no_space: serial_normalized_no_space)
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
