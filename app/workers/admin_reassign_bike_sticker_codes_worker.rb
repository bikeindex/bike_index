class AdminReassignBikeStickerCodesWorker < ApplicationWorker
  def perform(user_id, organization_id, bike_sticker_batch_id, first_sticker_id, last_sticker_id = nil)
    bike_sticker1 = BikeSticker.find(first_sticker_id)
    bike_sticker2 = BikeSticker.find(last_sticker_id)
    # If updating this query - also update the query in Admin::BikeStickersController
    bike_stickers = BikeSticker.where(bike_sticker_batch_id: bike_sticker_batch_id)
      .where("code_integer >= ?", bike_sticker1.code_integer)
    bike_stickers = bike_stickers.where("code_integer <= ?", bike_sticker2.code_integer) if bike_sticker2.present?
    # assign organization
    bike_stickers.where.not(organization_id: organization_id).update_all(organization_id: organization_id)
    # create bike_sticker_updates
    bike_stickers.each do |bike_sticker|
      # Skip creating an update if the last update did the same thing (in case job fails in the middle)
      last_update = bike_sticker.bike_sticker_updates.order(:id).last
      next if last_update.present? && last_update.kind == "admin_reassign" &&
        last_update.organization_id == organization_id
      BikeStickerUpdate.create(bike_sticker_id: bike_sticker.id,
        user_id: user_id,
        organization_id: organization_id,
        kind: "admin_reassign",
        organization_kind: "primary_organization")
    end
  end
end
