class BikeVersionCreatorWorker < ApplicationWorker
  sidekiq_options retry: false, queue: "high_priority"

  def perform(bike_id)
    bike = Bike.unscoped.find_by_id(bike_id)

  end
end
