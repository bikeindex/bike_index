# Recorded so the owner can later be asked to merge the two registrations
module BikeJobs
  class PosRegistrationMatchFinderJob < ApplicationJob
    sidekiq_options queue: "droppable", retry: 2

    POS_KINDS = %w[lightspeed_pos ascend_pos].freeze
    CUSTOMER_ORIGINS = (Ownership::ORIGIN_REG_FLOW + %w[web embed embed_extended embed_partial api_v2 api_v3]).freeze

    def perform(bike_id)
      bike = Bike.unscoped.find_by_id(bike_id)
      return unless bike.present? && live?(bike) && matchable_bike?(bike) && self_registration?(bike)

      pos_bikes = earlier_pos_bikes(bike)
      return if pos_bikes.count != 1 || entangled?([bike.id, pos_bikes.first.id]) ||
        stolen_history?(bike.serial_normalized_no_space)

      PosRegistrationMatch.create_or_find_by!(bike_id:, pos_bike_id: pos_bikes.first.id) { it.user_id = bike.user_id }
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
      bike_ids = Ownership.current.initial.where(user_id: bike.user_id, pos_kind: POS_KINDS)
        .where.not(bike_id: bike.id).pluck(:bike_id)
      return [] if bike_ids.none?

      Bike.unscoped.where(id: bike_ids, manufacturer_id: bike.manufacturer_id,
        serial_normalized_no_space: bike.serial_normalized_no_space,
        created_at: (bike.created_at - 365.days)...bike.created_at).select { live?(it) }
    end

    def entangled?(bike_ids)
      ImpoundRecord.where(bike_id: bike_ids).exists? ||
        MarketplaceListing.where(item_type: "Bike", item_id: bike_ids).exists? ||
        Ownership.transferred.where(bike_id: bike_ids).exists?
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
