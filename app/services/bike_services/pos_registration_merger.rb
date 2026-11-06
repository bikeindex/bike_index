# frozen_string_literal: true

# The owner confirmed their own registration is the bike their shop's POS registered. The POS registration
# stays, since it carries the shop and the sale, and takes what the owner added; their registration is deleted
module BikeServices
  module PosRegistrationMerger
    extend Functionable

    # Copied where the POS registration has none. Not the colors, serial or manufacturer, which it always has
    FILLED_ATTRIBUTES = %w[name frame_model year description frame_size frame_size_number frame_size_unit frame_material
      handlebar_type secondary_frame_color_id tertiary_frame_color_id paint_id front_wheel_size_id rear_wheel_size_id
      front_gear_type_id rear_gear_type_id primary_activity_id].freeze

    # Returns whether it merged. A theft, transfer, impound or listing since the match was recorded leaves
    # it for an admin, with the new reasons recorded
    def merge(match)
      bike = Bike.unscoped.find_by(id: match.bike_id)
      pos_bike = Bike.unscoped.find_by(id: match.pos_bike_id)
      return false unless mergeable?(match, bike, pos_bike)

      reasons = PosRegistrationMatch.review_reasons_for(bike, pos_bike)
      if reasons.any?
        match.add_review_reasons!(reasons)
        return false
      end

      ActiveRecord::Base.transaction do
        pos_bike.update!(FILLED_ATTRIBUTES.select { pos_bike[it].blank? && bike[it].present? }.index_with { bike[it] })
        bike.public_images.each { it.update!(imageable: pos_bike) }
        bike.components.update_all(bike_id: pos_bike.id)
        bike.bike_stickers.each { it.claim(bike: pos_bike, user: bike.user) }
        pos_bike.current_ownership.mark_claimed unless pos_bike.current_ownership.claimed?
        match.update!(status: :merged)
        bike.destroy!
      end
      [bike.id, pos_bike.id].each { CallbackJobs::AfterBikeSaveJob.perform_async(it) }
      true
    end

    def mergeable?(match, bike, pos_bike)
      return false unless match.pending? || match.confirmed?
      return false unless match.merge_candidate? && [bike, pos_bike].all? { it.present? && it.deleted_at.blank? && !it.example && !it.likely_spam }

      bike.user_id.present? && bike.user_id == pos_bike.user_id
    end
  end
end
