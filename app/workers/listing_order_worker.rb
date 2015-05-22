class ListingOrderWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true
    
  def perform(bike_id)
    bike = Bike.unscoped.where(id: bike_id).first
    bike.update_attribute :listing_order, bike.get_listing_order if bike.present?
    AfterBikeSaveWorker.perform_async(bike_id)
  end

end