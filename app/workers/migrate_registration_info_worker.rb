# TODO: remove once this has finished migrating, post merging #2035

class MigrateRegistrationInfoWorker < ApplicationWorker
  def perform(creation_state_id = nil, bike_id = nil)
    if creation_state_id.present?
      creation_state = CreationState.find_by_id(creation_state_id)
      bike = Bike.unscoped.find_by_id(creation_state.bike_id)
    else
      bike = Bike.unscoped.find_by_id(bike_id)
      creation_state = bike.fetch_current_creation_state
    end
    return unless bike.present? && bike.b_params.any?
    info_hashes = bike.b_params.order(created_at: :asc).map { |b| b.registration_info_attrs }.reject(&:blank?)
    if info_hashes.any?
      creation_state.update(registration_info: info_hashes.inject(&:merge).merge(bike.conditional_information))
    end
  end
end
