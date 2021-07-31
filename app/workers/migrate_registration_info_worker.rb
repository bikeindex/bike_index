# TODO: remove once this has finished migrating, post merging #2035

class MigrateRegistrationInfoWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  OFFSET_TIMESTAMP = ENV["MIGRATE_REGISTRATION_INFO_OFFSET"] || Time.current

  def self.frequency
    5.minutes
  end

  def perform(id = nil)
    return enqueue_workers unless id.present?
    creation_state = CreationState.find_by_id(id)
    bike = Bike.unscoped.find_by_id(creation_state.bike_id)
    return unless bike.present? && bike.b_params.any?
    info_hashes = bike.b_params.order(created_at: :asc).map { |b| b.registration_info_attrs }.reject(&:blank?)
    if info_hashes.any?
      creation_state.update(registration_info: info_hashes.inject(&:merge))
    end
  end

  def enqueue_workers
    offset = (Time.current.to_i - OFFSET_TIMESTAMP.to_i) / self.class.frequency.to_i
    limit = 10_000
    CreationState.where("id < ?", (offset + 1) * limit).where("id > ?", offset * limit)
      .where(registration_info: nil)
      .pluck(:id).each { |i| MigrateRegistrationInfoWorker.perform_async(i) }
  end
end
