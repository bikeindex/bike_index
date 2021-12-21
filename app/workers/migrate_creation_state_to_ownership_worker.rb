class MigrateCreationStateToOwnershipWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: false
  # This timestamp is when the migration started - so any creation_state with an updated_at *after* this timestamp
  # is assumed to be correct
  END_TIMESTAMP = ENV["CREATION_STATE_TIMESTAMP"] || 1640033379

  def self.creation_states
    CreationState.where("updated_at < ?", Time.at(END_TIMESTAMP))
      .order(updated_at: :desc)
  end

  def self.migrate?(creation_state, ownership)
    creation_state.updated_at.to_i < END_TIMESTAMP &&
      ownership.updated_at.to_i < END_TIMESTAMP
  end

  def perform(creation_state_id, ownership_id = nil)
    creation_state = CreationState.find(creation_state_id)
    bike = Bike.unscoped.find_by_id(creation_state.bike_id)
    # Break if this isn't as expected, until we have logic to handle it!
    raise "Multiple Creation States - Bike: #{bike.id}" if CreationState.where(bike_id: bike.id).count != 1

    ownership = if ownership_id.present?
      Ownership.find(ownership_id)
    else
      bike.ownerships.first
    end
    raise "No Ownership - Bike: #{bike.id}" if CreationState.where(bike_id: bike.id).count != 1
    registration_info = creation_state.registration_info || {}
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
