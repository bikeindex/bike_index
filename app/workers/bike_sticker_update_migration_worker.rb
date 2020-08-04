# NOTE: process them in claimed order, so we get IDs roughly in line with claim history
# BikeSticker.claimed.reorder(:claimed_at).pluck(:id)

class BikeStickerUpdateMigrationWorker < ApplicationWorker
  sidekiq_options queue: "low_priority"

  def perform(bike_sticker_id)
    bike_sticker = BikeSticker.find_by_id(bike_sticker_id)
    return true unless bike_sticker.present? && bike_sticker.claimed?
    user = bike_sticker.user
    bike_sticker_update = bike_sticker.bike_sticker_updates.new(bike_id: bike_sticker.bike_id,
                                                                created_at: bike_sticker.claimed_at,
                                                                kind: "initial_claim",
                                                                user: user)
    if bike_sticker.organization.present? && user.authorized?(bike_sticker.organization)
      update_organization = bike_sticker.organization
    elsif bike_sticker.organization.present? && bike_sticker.organization.regional?
      update_organization = user.organizations.where(id: bike_sticker.organization.regional_ids).first
      update_organization ||= user.organizations.ambassador.first
    end
    update_organization ||= user.organizations.first
    unless bike_sticker.organization == update_organization
      bike_sticker.update_column :secondary_organization_id, update_organization.id
    end
    bike_sticker_update.organization_id = update_organization.id
    bike_sticker_update.save!
  end
end
