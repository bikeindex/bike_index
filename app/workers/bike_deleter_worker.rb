class BikeDeleterWorker < ApplicationWorker
  sidekiq_options retry: false

  def perform(bike_id)
    Bike.where(id: bike_id).first&.destroy
  end
end
