# frozen_string_literal: true

# The owner confirmed their own registration is the bike their shop's POS registered. The POS registration
# stays, since it carries the shop and the sale, and takes what the owner added; their registration is deleted.
# Like UserJobs::MergeAdditionalEmailJob, everything pointing at the deleted registration is moved or listed here
module BikeJobs
  class MergePosRegistrationJob < ApplicationJob
    sidekiq_options queue: "high_priority"

    # The owner's value wins, unless it's blank or the column's own default, which can't be told apart from not choosing
    OWNER_ATTRIBUTES = %w[name description frame_model year cycle_type propulsion_type primary_frame_color_id
      secondary_frame_color_id tertiary_frame_color_id paint_id frame_material handlebar_type
      front_wheel_size_id rear_wheel_size_id front_tire_narrow rear_tire_narrow front_gear_type_id rear_gear_type_id
      belt_drive coaster_brake number_of_seats primary_activity_id extra_registration_number video_embed].freeze
    # Taken together, since a number from one and a unit from the other make a size neither entered
    FRAME_SIZE_ATTRIBUTES = %w[frame_size frame_size_number frame_size_unit].freeze

    # Moved over whole
    MOVED_MODELS = [BikeStickerUpdate, Component, CustomerContact, EducationCourseAcknowledgment, GraduatedNotification,
      Notification, OrganizationMessage, ParkingNotification, StolenBikeListing, StolenNotification].freeze
    # Tables with a bike_id merged by their own method below
    MERGED_TABLES = %w[address_records bike_organization_notes bike_organizations bike_stickers].freeze
    # Tables with a bike_id left on the deleted registration
    LEFT_TABLES = {
      "ownerships" => "the POS registration's ownership takes the owner's registration info",
      "normalized_serial_segments" => "removed by DuplicateBikeFinderJob once the registration is deleted",
      "user_alerts" => "recalculated for the owner by AfterBikeSaveJob",
      "pos_registration_matches" => "the record of the merge",
      "stolen_records" => "stolen history is a review reason, so there's none",
      "theft_alerts" => "these need a stolen record, which is a review reason",
      "impound_records" => "a review reason",
      "bike_versions" => "a review reason"
    }.freeze

    def perform(pos_registration_match_id)
      merged_match = with_redlock(pos_registration_match_id) do
        match = PosRegistrationMatch.find_by_id(pos_registration_match_id)
        next unless match&.merging?

        # Rechecked, since a theft, an edit or a transfer can come after the owner's answer
        reasons = if match.mergeable?
          PosRegistrationMatch.review_reasons_for(match.bike, match.pos_bike)
        else
          ["changed_since_confirmed"]
        end
        match.add_review_reasons!(reasons)
        next unless match.merge_candidate?

        ActiveRecord::Base.transaction do
          merge(match.bike, match.pos_bike)
          match.update!(status: :merged)
        end
        match
      end
      return if merged_match.blank?

      [merged_match.bike_id, merged_match.pos_bike_id].each { CallbackJobs::AfterBikeSaveJob.perform_async(it) }
    end

    private

    def merge(bike, pos_bike)
      MOVED_MODELS.each { it.unscoped.where(bike_id: bike.id).update_all(bike_id: pos_bike.id) }
      GraduatedNotification.unscoped.where(primary_bike_id: bike.id).update_all(primary_bike_id: pos_bike.id)
      PublicImage.unscoped.where(imageable: bike).update_all(imageable_id: pos_bike.id)
      Sale.where(item: bike).update_all(item_id: pos_bike.id)
      # Gear is its Strava athlete's
      unless StravaGear.where(item: pos_bike).exists?
        StravaGear.where(item: bike, strava_integration: StravaIntegration.where(user_id: pos_bike.user_id))
          .update_all(item_id: pos_bike.id)
      end
      bike.bike_stickers.each { it.claim(bike: pos_bike, user: bike.user) }
      merge_bike_organizations(bike, pos_bike)
      # One note per organization
      bike.bike_organization_notes.where.not(organization_id: pos_bike.bike_organization_notes.select(:organization_id))
        .update_all(bike_id: pos_bike.id)
      merge_attributes(bike, pos_bike)
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

    def merge_attributes(bike, pos_bike)
      if bike.address_set_manually && bike.address_record.present?
        bike.address_record.update!(bike_id: pos_bike.id)
        pos_bike.assign_attributes(address_record_id: bike.address_record_id, address_set_manually: true)
      end

      # The registration address is the initial ownership's, so the owner's goes with their registration info
      owner_ownership = bike.current_ownership
      pos_ownership = pos_bike.current_ownership
      owner_ownership&.address_record&.update!(bike_id: pos_bike.id)
      pos_ownership.update!(claimed: true, token: nil,
        registration_info: pos_ownership.registration_info.to_h.merge(owner_ownership&.registration_info.to_h.compact_blank),
        address_record_id: owner_ownership&.address_record_id || pos_ownership.address_record_id)

      # Blank isn't a choice, but a non-default false is
      pos_bike.assign_attributes(OWNER_ATTRIBUTES.reject { bike[it].to_s.blank? || bike[it] == Bike.column_defaults[it] }
        .index_with { bike[it] })
      pos_bike.assign_attributes(bike.slice(*FRAME_SIZE_ATTRIBUTES)) if bike.frame_size.present?
      pos_bike.assign_attributes(bike.user_hidden ? {marked_user_hidden: true} : {marked_user_unhidden: true})
    end
  end
end
