# frozen_string_literal: true

# The owner confirmed their own registration is the bike their shop's POS registered. The POS registration
# stays, since it carries the shop and the sale, and takes what the owner added; their registration is deleted
module BikeServices
  module PosRegistrationMerger
    extend Functionable

    # Shops often leave these at a default, so the owner's value wins unless it's the column's own default,
    # which can't be told apart from not choosing
    OWNER_ATTRIBUTES = %w[name description cycle_type propulsion_type primary_frame_color_id secondary_frame_color_id
      tertiary_frame_color_id paint_id frame_size frame_size_number frame_size_unit frame_material handlebar_type
      front_wheel_size_id rear_wheel_size_id front_tire_narrow rear_tire_narrow front_gear_type_id rear_gear_type_id
      belt_drive coaster_brake number_of_seats primary_activity_id extra_registration_number video_embed].freeze
    # From the sale, so the owner's value only fills a blank
    POS_ATTRIBUTES = %w[frame_model year].freeze

    # The owner said yes. Returns whether it merged; if it couldn't, the match is left confirmed, with any
    # review reasons that have come up since recorded
    def confirm(match, user:)
      merged = with_locked(match) do |bike, pos_bike|
        next false unless match.confirmable?(bike, pos_bike) && bike.user_id == user&.id

        match.update!(status: :confirmed)
        match.add_review_reasons!(PosRegistrationMatch.review_reasons_for(bike, pos_bike))
        next false unless match.merge_candidate?

        merge(bike, pos_bike)
        match.update!(status: :merged)
        true
      end
      [match.bike_id, match.pos_bike_id].each { CallbackJobs::AfterBikeSaveJob.perform_async(it) } if merged
      merged
    end

    def decline(match, user:)
      with_locked(match) do |bike, pos_bike|
        match.update!(status: :declined) if match.pending? && bike&.user_id == user&.id
      end
    end

    # private below here

    # The POS bike, then the match, the order the finder locks them in; then the registration
    def with_locked(match)
      pos_bike = Bike.unscoped.find_by(id: match.pos_bike_id)
      return false if pos_bike.blank?

      pos_bike.with_lock do
        match.lock!
        yield Bike.unscoped.lock.find_by(id: match.bike_id), pos_bike
      end
    end

    def merge(bike, pos_bike)
      PublicImage.unscoped.where(imageable: bike).update_all(imageable_id: pos_bike.id)
      bike.components.update_all(bike_id: pos_bike.id)
      bike.bike_stickers.each { it.claim(bike: pos_bike, user: bike.user) }
      merge_bike_organizations(bike, pos_bike)
      StravaGear.where(item: bike).update_all(item_id: pos_bike.id) unless StravaGear.where(item: pos_bike).exists?
      if bike.address_set_manually && bike.address_record.present?
        bike.address_record.update!(bike_id: pos_bike.id)
        pos_bike.assign_attributes(address_record_id: bike.address_record_id, address_set_manually: true)
      end

      # The registration address is the initial ownership's, so the owner's goes with their registration info
      owner_ownership = bike.current_ownership
      pos_ownership = pos_bike.current_ownership
      pos_ownership.update!(claimed: true, token: nil,
        registration_info: pos_ownership.registration_info.to_h.merge(owner_ownership&.registration_info.to_h.compact_blank),
        address_record_id: owner_ownership&.address_record_id || pos_ownership.address_record_id)

      pos_bike.assign_attributes(OWNER_ATTRIBUTES.reject { bike[it].nil? || bike[it] == Bike.column_defaults[it] }
        .index_with { bike[it] })
      pos_bike.assign_attributes(POS_ATTRIBUTES.select { pos_bike[it].blank? && bike[it].present? }.index_with { bike[it] })
      pos_bike.assign_attributes(bike.user_hidden ? {marked_user_hidden: true} : {marked_user_unhidden: true})
      pos_bike.save!
      bike.destroy!
    end

    # An organization on both keeps the more restrictive edit permission
    def merge_bike_organizations(bike, pos_bike)
      pos_bike_organizations = pos_bike.bike_organizations.index_by(&:organization_id)
      bike.bike_organizations.each do |bike_organization|
        pos_bike_organization = pos_bike_organizations[bike_organization.organization_id]
        if pos_bike_organization.blank?
          bike_organization.update_columns(bike_id: pos_bike.id)
        elsif bike_organization.can_not_edit_claimed && !pos_bike_organization.can_not_edit_claimed
          pos_bike_organization.update!(can_not_edit_claimed: true)
        end
      end
    end

    conceal :with_locked, :merge, :merge_bike_organizations
  end
end
