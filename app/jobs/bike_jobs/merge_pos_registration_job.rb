# frozen_string_literal: true

# The owner confirmed their own registration is the bike their shop's POS registered. The POS registration
# stays, since it carries the shop and the sale, and takes what the owner added; their registration is deleted.
# Like UserJobs::MergeAdditionalEmailJob, everything pointing at the deleted registration is moved or listed here
module BikeJobs
  class MergePosRegistrationJob < ApplicationJob
    sidekiq_options queue: "high_priority"

    # What the owner entered replaces the shop's, blank or not
    OWNER_ATTRIBUTES = %w[name description frame_model year cycle_type propulsion_type primary_frame_color_id
      secondary_frame_color_id tertiary_frame_color_id paint_id frame_material handlebar_type
      front_wheel_size_id rear_wheel_size_id front_tire_narrow rear_tire_narrow front_gear_type_id rear_gear_type_id
      belt_drive coaster_brake number_of_seats primary_activity_id extra_registration_number video_embed
      frame_size frame_size_number frame_size_unit].freeze

    # Moved over whole
    MOVED_MODELS = [BikeStickerUpdate, Component, CustomerContact, EducationCourseAcknowledgment, GraduatedNotification,
      Notification, OrganizationMessage, ParkingNotification, StolenBikeListing, StolenNotification].freeze
    # Other columns that can point at a bike, moved below
    MERGED_COLUMNS = %w[address_records.bike_id b_params.created_bike_id bike_organization_notes.bike_id
      bike_organizations.bike_id bike_stickers.bike_id graduated_notifications.primary_bike_id
      impound_claims.bike_submitting_id public_images.imageable_id sales.item_id strava_gears.item_id].freeze
    # Columns that can point at a bike, left on the deleted registration
    LEFT_COLUMNS = {
      "ownerships.bike_id" => "the POS registration's ownership takes the owner's registration info",
      "normalized_serial_segments.bike_id" => "removed by DuplicateBikeFinderJob once the registration is deleted",
      "user_alerts.bike_id" => "resolved, since the registration is gone",
      "pos_registration_matches.bike_id" => "the record of the merge",
      "pos_registration_matches.pos_bike_id" => "the owner's registration isn't a POS one",
      "bike_stickers.previous_bike_id" => "where a sticker was before, like a re-claim records",
      "stolen_records.bike_id" => "stolen history is a review reason, so there's none",
      "theft_alerts.bike_id" => "these need a stolen record, which is a review reason",
      "impound_records.bike_id" => "a review reason",
      "impound_claims.bike_claimed_id" => "the impounded bike, which is a review reason",
      "bike_versions.bike_id" => "a review reason",
      "marketplace_listings.item_id" => "a review reason",
      "notifications.notifiable_id" => "never a bike",
      "user_alerts.alertable_id" => "never a bike"
    }.freeze

    def perform(pos_registration_match_id)
      match = PosRegistrationMatch.find_by_id(pos_registration_match_id)
      return unless match&.merging?

      merged = ActiveRecord::Base.transaction do
        # Ownerships before bikes, the order saving an ownership takes them in, since it touches its bike. With the
        # POS bike locked, as the finder locks it, a new registration of it either is seen here or sees this merge.
        # With theirs locked, it can't be transferred mid-merge
        bike_ids = [match.bike_id, match.pos_bike_id]
        Ownership.current.where(bike_id: bike_ids).order(:id).lock.pluck(:id)
        Bike.unscoped.where(id: bike_ids).order(:id).lock.pluck(:id)
        match.reload
        next false unless match.merging?

        # A transfer's new ownership is current before its bike points to it. Read after the bike locks, so one that
        # committed while this waited is seen
        transferring = Ownership.current.where(bike_id: bike_ids).order(:id).pluck(:id) !=
          [match.bike, match.pos_bike].filter_map { it&.current_ownership_id }.sort
        # Rechecked, since a theft, an edit, a transfer or another registration can come after the owner's answer
        reasons = if match.mergeable? && !transferring
          PosRegistrationMatch.review_reasons_for(match.bike, match.pos_bike) +
            (PosRegistrationMatch.other_registration_matches(bike_id: match.bike_id, pos_bike_id: match.pos_bike_id)
              .exists? ? ["multiple_registrations"] : [])
        else
          ["changed_since_confirmed"]
        end
        match.add_review_reasons!(reasons)
        next false unless match.merge_candidate?

        merge(match.bike, match.pos_bike)
        match.update!(status: :merged, merged_at: Time.current)
      end
      return unless merged

      [match.bike_id, match.pos_bike_id].each { CallbackJobs::AfterBikeSaveJob.perform_async(it) }
    end

    private

    def merge(bike, pos_bike)
      MOVED_MODELS.each { it.unscoped.where(bike_id: bike.id).update_all(bike_id: pos_bike.id) }
      GraduatedNotification.unscoped.where(primary_bike_id: bike.id).update_all(primary_bike_id: pos_bike.id)
      # What they submitted, which a pending education course acknowledgment links to
      BParam.where(created_bike_id: bike.id).update_all(created_bike_id: pos_bike.id)
      ImpoundClaim.where(bike_submitting_id: bike.id).update_all(bike_submitting_id: pos_bike.id)
      # Recalculating alerts only visits live bikes. AfterBikeSaveJob refreshes the owner's alert slugs
      UserAlert.active.where(bike_id: bike.id).update_all(resolved_at: Time.current, updated_at: Time.current)
      PublicImage.unscoped.where(imageable: bike).update_all(imageable_id: pos_bike.id)
      Sale.where(item: bike).update_all(item_id: pos_bike.id)
      # Gear is its Strava athlete's
      unless StravaGear.where(item: pos_bike).exists?
        StravaGear.where(item: bike, strava_integration: StravaIntegration.where(user_id: pos_bike.user_id))
          .update_all(item_id: pos_bike.id)
      end
      # Moved rather than claimed, which would make the owner its claimer and add organizations. The update has
      # no user, so it doesn't count toward anyone's unorganized claims
      bike.bike_stickers.each do |bike_sticker|
        bike_sticker.update_columns(bike_id: pos_bike.id, previous_bike_id: bike.id, updated_at: Time.current)
        BikeStickerUpdate.create!(bike_sticker:, bike: pos_bike)
      end
      merge_bike_organizations(bike, pos_bike)
      # One note per organization
      bike.bike_organization_notes.where.not(organization_id: pos_bike.bike_organization_notes.select(:organization_id))
        .update_all(bike_id: pos_bike.id)
      merge_attributes(bike, pos_bike)
      pos_bike.save!
      bike.destroy!
    end

    # An organization on both keeps the more restrictive edit permission. Graduated (deleted) memberships come too,
    # since a graduated notification's renewal link restores its membership
    def merge_bike_organizations(bike, pos_bike)
      # A current membership over a graduated one
      pos_bike_organizations = BikeOrganization.unscoped.where(bike_id: pos_bike.id).sort_by { it.deleted? ? 0 : 1 }
        .index_by(&:organization_id)
      BikeOrganization.unscoped.where(bike_id: bike.id).each do |bike_organization|
        pos_bike_organization = pos_bike_organizations[bike_organization.organization_id]
        if pos_bike_organization.blank? || (pos_bike_organization.deleted? && !bike_organization.deleted?)
          bike_organization.update_columns(bike_id: pos_bike.id,
            can_not_edit_claimed: bike_organization.can_not_edit_claimed || !!pos_bike_organization&.can_not_edit_claimed)
          next
        end

        # The moved graduated notifications graduate the kept bike from the organization
        GraduatedNotification.unscoped.where(bike_organization_id: bike_organization.id)
          .update_all(bike_organization_id: pos_bike_organization.id)
        # Graduated ones too, since a renewal restores the kept bike's
        if bike_organization.can_not_edit_claimed && !pos_bike_organization.can_not_edit_claimed
          pos_bike_organization.update_columns(can_not_edit_claimed: true, updated_at: Time.current)
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

      pos_bike.assign_attributes(bike.slice(*OWNER_ATTRIBUTES))
      pos_bike.assign_attributes(bike.user_hidden ? {marked_user_hidden: true} : {marked_user_unhidden: true})
    end
  end
end
