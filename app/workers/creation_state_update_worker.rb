class CreationStateUpdateWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low_priority", backtrace: true

  def perform(creation_state_id)
    CreationState.find(creation_state_id)
                 .update_attributes(updated_at: Time.now)
  end
end
