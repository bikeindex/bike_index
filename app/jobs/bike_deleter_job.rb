class BikeDeleterJob < ApplicationJob
  sidekiq_options retry: false, queue: "low_priority"

  def perform(bike_id, really_delete = false, user_id = nil)
    if really_delete
      Ownership.where(bike_id:).destroy_all
      PublicImage.where(imageable_type: "Bike", imageable_id: bike_id).destroy_all
      Bike.unscoped.find_by_id(bike_id)&.really_destroy!
    else
      bike = Bike.unscoped.find_by_id(bike_id)
      bike.current_marketplace_listing&.update(status: "removed")
      if bike.current_impound_record.present?
        bike.current_impound_record.impound_record_updates.create(user_id:, kind: "removed_from_bike_index")
      end
      bike.destroy
    end
  end
end
