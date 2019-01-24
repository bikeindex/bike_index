class BikeDeleterWorker
  include Sidekiq::Worker
  sidekiq_options queue: "afterwards"
  sidekiq_options backtrace: true

  def perform(bike_id)
    bike = Bike.where(id: bike_id).first
    bike && bike.destroy
  end
end
