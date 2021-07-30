# TODO: remove once this has finished migrating, post merging #2035

class MigrateRegistrationInfoWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  OFFSET_TIMESTAMP = ENV["MIGRATE_REGISTRATION_INFO_OFFSET"] || Time.current.to_i

  def self.frequency
    10.minutes
  end

  def perform(bike_id = nil)
    return enqueue_workers unless bike_id.present?

  end

  def enqueue_workers
    # OFFSET_TIMESTAMP blah blah blah
  end
end
