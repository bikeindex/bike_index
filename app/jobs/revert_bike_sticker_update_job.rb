# NOTE: This was created to remove updates that were made in error
# it DELETES THE BIKE STICKER UPDATE IT IS PASSED
# only use this if you want to remove the history. Generally this is not the right thing

class RevertBikeStickerUpdateJob < ApplicationJob
  sidekiq_options retry: false

  def perform(bike_sticker_update_id)
    bike_sticker_update = BikeStickerUpdate.find_by_id(bike_sticker_update_id)
    return if bike_sticker_update.blank?

    bike_sticker = bike_sticker_update.bike_sticker

    bike_sticker.update!(previous_sticker_attributes(bike_sticker, bike_sticker_update))
    bike_sticker_update.destroy!
  end

  private

  def previous_sticker_attributes(bike_sticker, bike_sticker_update)
    previous_updates = bike_sticker.bike_sticker_updates.successful
      .where(update_number: ...bike_sticker_update.update_number)
      .order(update_number: :desc)

    following_updates = bike_sticker.bike_sticker_updates
      .where("update_number > ?", bike_sticker_update.update_number)

    if following_updates.present?
      raise "Following claim failed"

    elsif previous_updates.present?
      last_update = previous_updates.first
      previous_bike_id = previous_updates.second&.bike_id
      secondary_organization_id = previous_updates.other_paid_organization.first&.organization_id
      last_update.slice(:bike_id, :user_id).merge(claimed_at: last_update.created_at,
        previous_bike_id:, secondary_organization_id:)
    else
      {bike_id: nil, user_id: nil, claimed_at: nil, secondary_organization_id: nil}
    end
  end
end
