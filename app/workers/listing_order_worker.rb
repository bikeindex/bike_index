class ListingOrderWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true
    
  def perform(bike_id)
    bike = Bike.find(bike_id)
    bike.update_attribute :listing_order, bike.get_listing_order
  end

end