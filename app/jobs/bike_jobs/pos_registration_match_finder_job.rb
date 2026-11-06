# Recorded so the owner can later be asked to merge the two registrations
module BikeJobs
  class PosRegistrationMatchFinderJob < ApplicationJob
    sidekiq_options queue: "droppable", retry: 2

    # Owners registering their own bike, including from the app (the API). Not organization_form, which shop staff fill in
    CUSTOMER_ORIGINS = (Ownership::ORIGIN_REG_FLOW + %w[web embed embed_extended embed_partial sticker api_v2 api_v3]).freeze

    def perform(bike_id)
      bike = Bike.unscoped.find_by_id(bike_id)
      return unless live?(bike) && matchable_bike?(bike) && self_registration?(bike)

      pos_bikes = earlier_pos_bikes(bike)
      return if pos_bikes.none?

      duplicate_bike_group_id = bike.normalized_serial_segments.where(segment: bike.serial_normalized_no_space).pick(:duplicate_bike_group_id)
      return if duplicate_bike_group_id.blank?

      pos_bikes.each do |pos_bike|
        reasons = PosRegistrationMatch.review_reasons_for(bike, pos_bike) + (pos_bikes.many? ? ["multiple_pos_bikes"] : [])
        # Locks the POS bike, so concurrent registrations of it each see the other's match
        match = pos_bike.with_lock do
          other_matches = PosRegistrationMatch.where(pos_bike_id: pos_bike.id).where.not(bike_id: bike.id)
            .select { live?(Bike.unscoped.find_by(id: it.bike_id)) }
          reasons += ["multiple_registrations"] if other_matches.any?
          other_matches.select(&:pending?).each { add_reasons(it, ["multiple_registrations"]) }
          record_match(bike, pos_bike, duplicate_bike_group_id, reasons)
        end
        # After the lock's transaction commits, so the email job finds the match
        EmailJobs::PosRegistrationMatchJob.perform_async(match.id) if match.previously_new_record? && match.merge_candidate?
      end
    end

    private

    def live?(bike)
      bike.present? && bike.deleted_at.blank? && !bike.example && !bike.likely_spam
    end

    def matchable_bike?(bike)
      bike.manufacturer.present? && !bike.manufacturer.other? &&
        bike.serial_normalized_no_space.to_s.length >= 6
    end

    def self_registration?(bike)
      ownership = bike.current_ownership
      ownership&.self_made? && !ownership.pos? && CUSTOMER_ORIGINS.include?(ownership.origin)
    end

    # Starts from the owner's ownerships (indexed) so most runs never query bikes by serial. The register flow
    # credits a customer's registration to their shop by default, so it can share the POS bike's organization
    def earlier_pos_bikes(bike)
      pos_bike_ids = Ownership.current.initial.where(user_id: bike.user_id, pos_kind: BikeDuplicatesServices::Finder::POS_KINDS).pluck(:bike_id)
      return [] if pos_bike_ids.none?

      BikeDuplicatesServices::Finder.serial_bikes(bike).where(id: pos_bike_ids, created_at: (bike.created_at - 365.days)...bike.created_at)
        .select { bike.creation_organization_id.in?([nil, it.creation_organization_id]) }
    end

    def record_match(bike, pos_bike, duplicate_bike_group_id, reasons)
      match = PosRegistrationMatch.create_or_find_by!(bike_id: bike.id, pos_bike_id: pos_bike.id) do
        it.duplicate_bike_group_id = duplicate_bike_group_id
        it.review_reasons = PosRegistrationMatch.ordered_reasons(reasons)
      end
      # A rerun only adds reasons, so it can't clear an earlier stolen veto; the group may have been replaced since
      add_reasons(match, reasons, duplicate_bike_group_id:) unless match.previously_new_record?
      match
    end

    def add_reasons(match, reasons, **attributes)
      match.add_review_reasons!(reasons, **attributes) if match.pending?
    end
  end
end
