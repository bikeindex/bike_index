class MigrateCreationStateToOwnershipWorker < ApplicationWorker
  sidekiq_options queue: "low_priority"
  # This timestamp is when the migration started - so any creation_state with an updated_at *after* this timestamp
  # is assumed to be correct
  END_TIMESTAMP = 1640033379

  def self.migrate?(creation_state, ownership)
    creation_state.updated_at.to_i < END_TIMESTAMP &&
      ownership.updated_at.to_i < END_TIMESTAMP
  end

  def perform(creation_state_id)

  end
end
