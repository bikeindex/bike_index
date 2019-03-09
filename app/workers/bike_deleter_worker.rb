class BikeDeleterWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low_priority"
  sidekiq_options backtrace: true

  def perform(bike_id)
    Bike.where(id: bike_id).first&.destroy
  end
end
