class BikeDeleterJob < ApplicationJob
  sidekiq_options retry: false, queue: "low_priority"

  def perform(bike_id, really_delete = false, user_id = nil)
    bike = Bike.unscoped.find_by_id(bike_id)
    return if bike.blank?

    bike.current_marketplace_listing&.update(status: "removed")
    if bike.current_impound_record.present?
      bike.current_impound_record.impound_record_updates.create(user_id:, kind: "removed_from_bike_index")
    end

    if really_delete
      Ownership.where(bike_id:).destroy_all
      PublicImage.where(imageable_type: "Bike", imageable_id: bike_id).destroy_all
      bike.really_destroy!
    else
      bike.destroy
      CallbackJob::AfterBikeSaveJob.perform_async(bike_id)
    end
  end
end
