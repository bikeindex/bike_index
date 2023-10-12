class MigrateNormalizedSerialSegmentsWorker < ApplicationWorker
  prepend ScheduledWorkerRecorder

  NUMBER_TO_ENQUEUE = ENV.fetch("SEGMENTS_WORKER_LIMIT", 1000).to_i.freeze

  sidekiq_options retry: false

  def self.frequency
    4.minutes
  end

  def self.potential_bikes
    Bike.where(serial_segments_migrated_at: nil)
  end

  def perform(bike_id = nil)
    return enqueue_workers if bike_id.nil?

    bike = Bike.unscoped.find_by_id(bike_id)
    return true if bike.blank?

    should_delete = bike.blank? || bike.deleted_at.present? || bike.example ||
      bike.likely_spam

    serial_segments = NormalizedSerialSegment.where(bike_id: bike_id)

    unless should_delete
      normalized_segments = SerialNormalizer.new(serial: bike.serial_normalized).normalized_segments
      (normalized_segments - serial_segments.pluck(:segment)).each do |segment|
        NormalizedSerialSegment.create(bike_id: bike_id, segment: segment)
      end
    end

    # TODO: remove ability to pass in bike when removing migration
    DuplicateBikeFinderWorker.new.perform(bike.id, bike)
  end

  def enqueue_workers
    return if NUMBER_TO_ENQUEUE == 0
    self.class.potential_bikes.limit(NUMBER_TO_ENQUEUE).pluck(:id)
      .each { |id| self.class.perform_async(id) }
  end
end
