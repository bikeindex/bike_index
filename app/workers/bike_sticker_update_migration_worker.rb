# NOTE: process them in claimed order, so we get IDs roughly in line with claim history
# BikeSticker.claimed.reorder(:claimed_at).pluck(:id)
# ... and after migration, remove this worker and BikeSticker#previous_bike_id
class BikeStickerUpdateMigrationWorker < ApplicationWorker
  sidekiq_options queue: "low_priority"

  def perform(bike_sticker_id)
    bike_sticker = BikeSticker.find_by_id(bike_sticker_id)
    return true unless bike_sticker.present?
    if bike_sticker.previous_bike_id.present?
      earlier_claimed_at = bike_sticker.claimed_at || bike_sticker.updated_at
      earlier_update = bike_sticker.bike_sticker_updates.new(bike_id: bike_sticker.previous_bike_id,
                                                              created_at: earlier_claimed_at - 1.hour,
                                                                kind: "initial_claim")
      earlier_update.save!
    end
    return true unless bike_sticker.claimed?
    user = bike_sticker.user
    bike_sticker_update = bike_sticker.bike_sticker_updates.new(bike_id: bike_sticker.bike_id,
                                                                created_at: bike_sticker.claimed_at,
                                                                kind: earlier_update.present? ? "re_claim" : "initial_claim",
                                                                user: user)
    bike_sticker_update.save!
    return true if bike_sticker_update.organization.blank? || bike_sticker.organization == bike_sticker_update.organization
    bike_sticker.update_column :secondary_organization_id, bike_sticker_update.organization_id
  end
end
