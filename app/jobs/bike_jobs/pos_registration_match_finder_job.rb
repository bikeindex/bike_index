# Recorded so the owner can later be asked to merge the two registrations. Stolen history, entanglements,
# several matching registrations or a serial that isn't one make the match a review candidate rather than a merge candidate
module BikeJobs
  class PosRegistrationMatchFinderJob < ApplicationJob
    sidekiq_options queue: "droppable", retry: 2

    CUSTOMER_ORIGINS = (Ownership::ORIGIN_REG_FLOW + %w[web embed embed_extended embed_partial sticker api_v2 api_v3]).freeze

    def perform(bike_id)
      bike = Bike.unscoped.find_by_id(bike_id)
      return unless bike.present? && live?(bike) && matchable_bike?(bike) && self_registration?(bike)

      pos_bikes = earlier_pos_bikes(bike)
      return if pos_bikes.none?

      shared_reasons = serial_review_reasons(bike.serial_normalized_no_space)
      shared_reasons << "multiple_pos_bikes" if pos_bikes.many?
      pos_bikes.each do |pos_bike|
        other_matches = PosRegistrationMatch.where(pos_bike_id: pos_bike.id).where.not(bike_id: bike.id)
        reasons = shared_reasons + entanglements([bike.id, pos_bike.id])
        reasons << "multiple_registrations" if other_matches.exists?
        record_match(bike, pos_bike, reasons)
        # An earlier registration's match was recorded before this one existed
        other_matches.pending.each { add_reasons(it, ["multiple_registrations"]) }
      end
    end

    private

    def live?(bike)
      bike.deleted_at.blank? && !bike.example && !bike.likely_spam
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
      bike_ids = Ownership.current.initial.where(user_id: bike.user_id, pos_kind: BikeDuplicatesServices::Finder::POS_KINDS)
        .pluck(:bike_id)
      return [] if bike_ids.none?

      Bike.unscoped.where(id: bike_ids, manufacturer_id: bike.manufacturer_id,
        serial_normalized_no_space: bike.serial_normalized_no_space,
        created_at: (bike.created_at - 365.days)...bike.created_at)
        .select { live?(it) && bike.creation_organization_id.in?([nil, it.creation_organization_id]) }
    end

    def serial_review_reasons(serial)
      not_a_serial = BikeDuplicatesServices::Cues.not_a_serial(serial,
        manufacturer_names: BikeDuplicatesServices::Cues.fetch_manufacturer_name_serials)
      [("stolen_history" if BikeDuplicatesServices::Finder.stolen_serials?([serial])),
        ("not_a_serial" if not_a_serial)].compact
    end

    def entanglements(bike_ids)
      listings = MarketplaceListing.where(item_type: "Bike", item_id: bike_ids)
        .or(MarketplaceListing.where(item_type: "BikeVersion", item_id: BikeVersion.where(bike_id: bike_ids).select(:id)))
      [("impounded" if ImpoundRecord.where(bike_id: bike_ids).exists?),
        ("marketplace_listing" if listings.exists?)].compact
    end

    def record_match(bike, pos_bike, reasons)
      match = PosRegistrationMatch.create_or_find_by!(bike_id: bike.id, pos_bike_id: pos_bike.id) do
        it.user_id = bike.user_id
        it.review_reasons = ordered(reasons)
      end
      # Reasons are recomputed while pending, except stolen history: an overlapping run that read the
      # serial before a theft was reported can't clear the veto
      match.with_lock { match.update!(review_reasons: ordered(reasons + match.review_reasons.intersection(%w[stolen_history]))) if match.pending? }
    end

    def add_reasons(match, reasons)
      match.with_lock { match.update!(review_reasons: ordered(match.review_reasons + reasons)) if match.pending? }
    end

    def ordered(reasons) = PosRegistrationMatch::REVIEW_REASONS.keys & reasons
  end
end
