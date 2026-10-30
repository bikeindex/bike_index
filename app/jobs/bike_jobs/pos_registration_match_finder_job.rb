# Recorded so the owner can later be asked to merge the two registrations. Stolen history, entanglements,
# several POS matches or a serial that isn't one make the match a review candidate rather than a merge candidate
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
        # In REVIEW_REASONS order
        review_reasons = PosRegistrationMatch::REVIEW_REASONS.keys & (shared_reasons + entanglements([bike.id, pos_bike.id]))
        # Theft can be reported after this, so whatever acts on a merge candidate re-checks the veto then
        match = PosRegistrationMatch.create_or_find_by!(bike_id:, pos_bike_id: pos_bike.id) do
          it.user_id = bike.user_id
          it.review_reasons = review_reasons
        end
        match.update!(review_reasons:) if match.pending?
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
      ownership&.self_made? &&
        ownership.organization_id.blank? && bike.creation_organization_id.blank? &&
        !ownership.pos? && CUSTOMER_ORIGINS.include?(ownership.origin)
    end

    # Starts from the owner's ownerships (indexed) so most runs never query bikes by serial
    def earlier_pos_bikes(bike)
      bike_ids = Ownership.current.initial.where(user_id: bike.user_id, pos_kind: BikeDuplicatesServices::Finder::POS_KINDS)
        .where.not(bike_id: bike.id).pluck(:bike_id)
      return [] if bike_ids.none?

      Bike.unscoped.where(id: bike_ids, manufacturer_id: bike.manufacturer_id,
        serial_normalized_no_space: bike.serial_normalized_no_space,
        created_at: (bike.created_at - 365.days)...bike.created_at).select { live?(it) }
    end

    def serial_review_reasons(serial)
      not_a_serial = BikeDuplicatesServices::Cues.not_a_serial(serial,
        manufacturer_names: BikeDuplicatesServices::Cues.fetch_manufacturer_name_serials)
      [("stolen_history" if stolen_history?(serial)), ("not_a_serial" if not_a_serial)].compact
    end

    def entanglements(bike_ids)
      [("transferred" if Ownership.transferred.where(bike_id: bike_ids).exists?),
        ("impounded" if ImpoundRecord.where(bike_id: bike_ids).exists?),
        ("marketplace_listing" if MarketplaceListing.where(item_type: "Bike", item_id: bike_ids).exists?)].compact
    end

    # Any manufacturer, including deleted and example bikes. Unindexed outside current bikes,
    # which is acceptable here
    def stolen_history?(serial)
      serial_bikes = Bike.unscoped.where(serial_normalized_no_space: serial)
      serial_bikes.where(status: "status_stolen").or(serial_bikes.where.not(current_stolen_record_id: nil)).exists? ||
        StolenRecord.current_and_not.where(bike_id: serial_bikes.select(:id)).exists?
    end
  end
end
