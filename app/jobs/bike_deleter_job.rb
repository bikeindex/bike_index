class BikeDeleterJob < ApplicationJob
  sidekiq_options retry: false, queue: "low_priority"

  def perform(bike_id, really_delete=false)
    if really_delete
      Ownership.where(bike_id:).destroy_all
      Bike.unscoped.find_by_id(bike_id).really_destroy!
    else
      Bike.unscoped.find_by_id(bike_id).destroy
    end
  end
end
