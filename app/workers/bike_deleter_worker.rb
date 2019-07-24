class BikeDeleterWorker < ApplicationWorker
  def perform(bike_id)
    Bike.where(id: bike_id).first&.destroy
  end
end
