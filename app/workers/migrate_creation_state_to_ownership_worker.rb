# add_reference :ownerships, :organization, index: true
# add_reference :ownerships, :bulk_import, index: true
# add_reference :bikes, :soon_current_ownership, index: true # Rename in future migration!
# Enums
# add_column :ownerships, :origin, :integer
# add_column :ownerships, :status, :integer
# add_column :ownerships, :pos_kind, :integer
# Extra stuff
# add_column :ownerships, :organization_pre_registration, :boolean, default: false
# add_column :ownerships, :owner_name, :string
# add_column :ownerships, :registration_info, :jsonb, default: {}

class MigrateCreationStateToOwnershipWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: false
  # This timestamp is when the migration started - so any creation_state with an updated_at *after* this timestamp
  # is assumed to be correct
  END_TIMESTAMP = 1640033379

  def self.migrate?(creation_state, ownership)
    creation_state.updated_at.to_i < END_TIMESTAMP &&
      ownership.updated_at.to_i < END_TIMESTAMP
  end

  def perform(creation_state_id, ownership_id = nil)
    creation_state = CreationState.find(creation_state_id)
    bike = Bike.unscoped.find_by_id(creation_state.bike_id)
    # Break if this isn't as expected, until we have logic to handle it!
    raise if CreationState.where(bike_id: bike.id).count != 1

    ownership = if ownership_id.present?
      Ownership.find(ownership_id)
    else
      bike.ownerships.first
    end
    registration_info = creation_state.registration_info || {}
    ownership.attributes = {
      organization_id: creation_state.organization_id,
      bulk_import_id: creation_state.bulk_import_id,
      registration_info: registration_info.except("user_name"),
      origin: creation_state.origin_enum,
      status: creation_state.status,
      pos_kind: creation_state.pos_kind,
      owner_name: registration_info["user_name"]
    }
    ownership.origin = "api_v1" if ownership.lightspeed_pos?
    ownership.organization_pre_registration = ownership.send("calculated_organization_pre_registration?")
    ownership.save
    creation_state.touch # To make sure it no longer is valid for migrate?
  end
end
