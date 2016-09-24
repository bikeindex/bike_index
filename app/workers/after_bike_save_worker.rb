class AfterBikeSaveWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates', backtrace: true, retry: false

  def perform(bike_id)
    bike = Bike.unscoped.where(id: bike_id).first
    if bike.present?
      DuplicateBikeFinderWorker.perform_async(bike_id)
      if bike.present? && bike.listing_order != bike.get_listing_order
        bike.update_attribute :listing_order, bike.get_listing_order
      end
    end
  end
end
