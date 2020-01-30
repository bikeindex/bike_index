class MigrationAddStateToBikesWorker < ApplicationWorker
  sidekiq_options queue: "low_priority"

  def perform(bike_id)
    bike = Bike.unscoped.find(bike_id)
    bike.update_attribute(:state, bike.calculated_state)
    return true unless bike.creation_state.present?
    # If the bike is set to "abandoned", make creation state abandoned
    if bike.abandoned
      bike.creation_state.update_attribute :state, "state_abandoned"
      return true
    end
    stolen_records = StolenRecord.unscoped.where(bike_id: bike.id)
    # if there is a stolen record created within a day of the bike's creation, make creation state stolen
    return true unless stolen_records.where(created_at: (bike.created_at - 1.day)..(bike.created_at + 1.day)).any?
    bike.creation_state.update_attribute :state, "state_stolen"
  end
end
