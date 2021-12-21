class MigrateCreationStateToOwnershipWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: false
  # This timestamp is when the migration started - so any creation_state with an updated_at *after* this timestamp
  # is assumed to be correct
  END_TIMESTAMP = 1640109567

  def self.creation_states
    CreationState.where("updated_at < ?", Time.at(END_TIMESTAMP))
      .order(updated_at: :desc)
  end

  def self.migrate?(creation_state, ownership)
    creation_state.updated_at.to_i < END_TIMESTAMP &&
      ownership.created_at.to_i < END_TIMESTAMP
  end

  def self.creation_states_with_earlier
    CreationState.where("updated_at > ?", Time.at(END_TIMESTAMP))
      .where(ownership_id: nil)
  end

  def perform(creation_state_id, ownership_id = nil)
    creation_state = CreationState.find_by_id(creation_state_id)
    return if creation_state.blank?
    return if earlier_duplicate_creation_states?(creation_state)

    bike = Bike.unscoped.find_by_id(creation_state.bike_id)

    ownership = if ownership_id.present?
      Ownership.find(ownership_id)
    else
      bike.ownerships.first
    end

    if ownership.blank?
      # We want to update if possible - even if the bike is deleted, so don't check deleted before now
      raise "No Ownership - Bike: #{bike.id}" unless bike.deleted?
    else
      migrate(creation_state, ownership, bike)
    end
  end

  def earlier_duplicate_creation_states?(creation_state)
    # Handle duplicate creation states
    other_creation_states = CreationState.where(bike_id: creation_state.bike_id).where.not(id: creation_state.id)
    matching_creation_states = other_creation_states.select do |ocs|
      ocs.attributes.except("id", "created_at", "updated_at") == creation_state.attributes.except("id", "created_at", "updated_at")
    end
    matching_ids = matching_creation_states.map(&:id)
    if matching_creation_states.any?
      creation_state.update(registration_info: creation_state.registration_info.merge("deleted_creation_states" => matching_ids))
      matching_creation_states.map(&:destroy)
    end
    # Exit this method if there are no earlier creation states
    if other_creation_states.where.not(id: matching_ids).where("id < ?", creation_state.id).none?
      return false
    end
    creation_state.touch
    true
  end

  def migrate(creation_state, ownership, bike)
    registration_info = creation_state.registration_info || {}
    registration_info = registration_info.except("deleted_creation_states")
    ownership.attributes = {
      organization_id: creation_state.organization_id,
      bulk_import_id: creation_state.bulk_import_id,
      registration_info: registration_info.except("user_name"),
      origin: creation_state.origin_enum,
      status: creation_state.status,
      pos_kind: creation_state.pos_kind,
      is_new: creation_state.is_new,
      owner_name: registration_info["user_name"]
    }
    ownership.origin = "api_v1" if ownership.lightspeed_pos?
    ownership.organization_pre_registration = ownership.send("calculated_organization_pre_registration?")
    ownership.save
    creation_state.update(ownership_id: ownership.id)
  end
end
