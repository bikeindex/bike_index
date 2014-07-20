class BikeSaveWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true
    
  def perform(bike_id)
    Bike.find(bike_id).save
  end

end