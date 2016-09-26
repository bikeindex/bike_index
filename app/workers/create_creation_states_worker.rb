class CreateCreationStatesWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'afterwards', backtrace: true, retry: false

  def perform(offset)
    current = offset - 1
    while current < offset + 101
      current += 1
      b = Bike.unscoped.find(current)
      next unless b.present?
      creation_state = CreationState.where(bike_id: b.id).first
      creation_state ||= CreationState.new(bike_id: b.id)
      creation_state.is_new ||= b.registered_new || false
      creation_state.is_pos ||= b.registered_new || false
      creation_state.update_attributes(creator_id: b.creator_id, organization_id: b.creation_organization_id)
    end
  end
end