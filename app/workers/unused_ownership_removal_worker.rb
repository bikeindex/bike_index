class UnusedOwnershipRemovalWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low_priority", backtrace: true

  def perform(id)
    ownership = Ownership.find(id)
    unless Bike.unscoped.where(id: ownership.bike_id).present?
      ownership.update_attribute :current, false
    end
  end
end
