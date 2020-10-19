class PreviousOwnershipMigrationWorker < ApplicationWorker
  def perform(bike_id)
    bike = Bike.unscoped.find_by_id(bike_id)
    return true unless bike.present? && bike.ownerships.count > 1
    ownerships.each { |o| o.update(updated_at: Time.current) }
  end
end
