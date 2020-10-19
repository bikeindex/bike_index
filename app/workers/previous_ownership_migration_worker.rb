class PreviousOwnershipMigrationWorker < ApplicationWorker
  def perform(bike_id)
    bike = Bike.where(id: bike_id).first
    return true unless bike.present? && bike.ownerships.count > 1
    ownerships.each { |o| o.update(updated_at: Time.current) }
  end
end
