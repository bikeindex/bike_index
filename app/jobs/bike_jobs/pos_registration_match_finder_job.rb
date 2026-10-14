# Records when a new self-registration matches the same owner's earlier POS registration,
# so they can later be asked to merge the two. Nothing else is done with the match yet
module BikeJobs
  class PosRegistrationMatchFinderJob < ApplicationJob
    sidekiq_options queue: "droppable", retry: 2

    POS_KINDS = %w[lightspeed_pos ascend_pos].freeze
    CUSTOMER_ORIGINS = (Ownership::ORIGIN_REG_FLOW + %w[web embed embed_extended embed_partial api_v2 api_v3]).freeze

    def perform(bike_id)
      bike = Bike.unscoped.find_by_id(bike_id)
      return unless bike.present? && live?(bike) && matchable_bike?(bike) && self_registration?(bike)

      # Unindexed for anything but current bikes, which is acceptable in a background job
      serial_bikes = Bike.unscoped.where(serial_normalized_no_space: bike.serial_normalized_no_space).to_a
      return if stolen_history?(serial_bikes)

      user_id = bike.current_ownership.user_id
      pos_bikes = serial_bikes.select { earlier_pos_registration?(it, bike:, user_id:) }
      return if pos_bikes.count != 1 || entangled?([bike.id, pos_bikes.first.id])

      PosRegistrationMatch.create_or_find_by!(bike_id:, pos_bike_id: pos_bikes.first.id) { it.user_id = user_id }
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
      ownership.present? && ownership.self_made? &&
        ownership.organization_id.blank? && bike.creation_organization_id.blank? &&
        !ownership.pos? && CUSTOMER_ORIGINS.include?(ownership.origin)
    end

    # Stolen history on the serial vetoes regardless of manufacturer or whether the bike is deleted
    def stolen_history?(serial_bikes)
      serial_bikes.any? { it.status_stolen? || it.current_stolen_record_id.present? } ||
        StolenRecord.unscoped.where(bike_id: serial_bikes.map(&:id)).exists?
    end

    def earlier_pos_registration?(other_bike, bike:, user_id:)
      other_bike.id != bike.id && live?(other_bike) && other_bike.manufacturer_id == bike.manufacturer_id &&
        other_bike.created_at < bike.created_at && other_bike.created_at > bike.created_at - 365.days &&
        POS_KINDS.include?(other_bike.ownerships.initial.first&.pos_kind) &&
        other_bike.current_ownership&.user_id == user_id
    end

    def entangled?(bike_ids)
      ImpoundRecord.where(bike_id: bike_ids).exists? ||
        MarketplaceListing.where(item_type: "Bike", item_id: bike_ids).exists? ||
        Ownership.transferred.where(bike_id: bike_ids).exists?
    end
  end
end
