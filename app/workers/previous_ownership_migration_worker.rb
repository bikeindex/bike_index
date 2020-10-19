# TODO: remove this, also make the ownership #first? use the previous ownership call
class PreviousOwnershipMigrationWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: false

  def perform(bike_id)
    bike = Bike.unscoped.find_by_id(bike_id)
    return true unless bike.present? && bike.ownerships.count > 1
    bike.ownerships.each { |o| o.update(updated_at: Time.current, previous_ownership_id: o.prior_ownerships.pluck(:id).last) }
  end
end
