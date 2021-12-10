class BikeDeleterWorker < ApplicationWorker
  sidekiq_options retry: false

  def perform(bike_id)
    Bike.unscoped.find_by_id(bike_id).destroy
  end
end
