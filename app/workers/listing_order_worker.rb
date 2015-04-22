class ListingOrderWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true
    
  def perform(bike_id)
    bike = Bike.unscoped.where(id: bike_id).first
    if bike.present?
      bike.update_attribute :listing_order, bike.get_listing_order
      AfterUserChangeWorker.perform_async(bike.owner.id) if bike.owner.present?
    end
    AfterBikeSaveWorker.perform_async(bike_id)
  end

end