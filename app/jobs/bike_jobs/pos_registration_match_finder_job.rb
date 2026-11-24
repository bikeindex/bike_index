# Recorded so the owner, or the other email the shop registered it to, can be asked to merge the two registrations
module BikeJobs
  class PosRegistrationMatchFinderJob < ApplicationJob
    sidekiq_options queue: "droppable", retry: 2

    # Owners registering their own bike, including from the app (the API). Not organization_form, which shop staff fill in
    CUSTOMER_ORIGINS = (Ownership::ORIGIN_REG_FLOW + %w[web embed embed_extended embed_partial sticker api_v2 api_v3]).freeze

    def perform(bike_id)
      bike = Bike.unscoped.find_by_id(bike_id)
      return unless bike&.current_with_user_hidden? && matchable_bike?(bike) && self_registration?(bike)

      duplicate_bike_group_id = bike.normalized_serial_segments.where(segment: bike.serial_normalized_no_space).pick(:duplicate_bike_group_id)
      return if duplicate_bike_group_id.blank?

      pos_bikes = earlier_pos_bikes(bike, duplicate_bike_group_id)
      return if pos_bikes.none?

      multiple_pos_bikes = pos_bikes.many? ? ["multiple_pos_bikes"] : []
      pos_bikes.each do |pos_bike|
        reasons = PosRegistrationMatch.review_reasons_for(bike, pos_bike) + multiple_pos_bikes
        # Locks the POS bike, so concurrent registrations of it each see the other's match
        match = pos_bike.with_lock do
          other_matches = PosRegistrationMatch.other_registration_matches(bike_id: bike.id, pos_bike_id: pos_bike.id).to_a
          reasons += ["multiple_registrations"] if other_matches.any?
          other_matches.each { add_reasons(it, ["multiple_registrations"]) }
          record_match(bike, pos_bike, duplicate_bike_group_id, reasons)
        end
        # After the lock's transaction commits, so the email job finds the match. Until it's sent, so a failed
        # enqueue or send is retried while the new registration is still being matched
        if match.pending? && match.merge_candidate? && !Notification.pos_registration_match.settled.exists?(notifiable: match)
          EmailJobs::PosRegistrationMatchJob.perform_async(match.id)
        end
      end
    end

    private

    def matchable_bike?(bike)
      bike.manufacturer.present? && !bike.manufacturer.other? &&
        bike.serial_normalized_no_space.to_s.length >= 6
    end

    def self_registration?(bike)
      ownership = bike.current_ownership
      ownership&.self_made? && !ownership.pos? && CUSTOMER_ORIGINS.include?(ownership.origin)
    end

    # The group's bikes (bikes has no index on serial) the shop's POS registered, still with their first owner: the
    # owner, or another email no account has claimed. The register flow credits a customer's registration to their
    # shop by default, so it can share the POS bike's organization
    def earlier_pos_bikes(bike, duplicate_bike_group_id)
      BikeDuplicatesServices::Finder.serial_bikes(bike).includes(:current_ownership)
        .where(id: NormalizedSerialSegment.where(duplicate_bike_group_id:).select(:bike_id),
          created_at: (bike.created_at - 365.days)...bike.created_at)
        .select do |pos_bike|
          ownership = pos_bike.current_ownership
          ownership&.initial? && ownership.pos_kind.in?(BikeDuplicatesServices::Finder::POS_KINDS) &&
            (ownership.user_id == bike.user_id || !ownership.claimed?) &&
            bike.creation_organization_id.in?([nil, pos_bike.creation_organization_id])
        end
    end

    def record_match(bike, pos_bike, duplicate_bike_group_id, reasons)
      match = PosRegistrationMatch.create_or_find_by!(bike_id: bike.id, pos_bike_id: pos_bike.id) do
        it.duplicate_bike_group_id = duplicate_bike_group_id
        it.review_reasons = PosRegistrationMatch.ordered_reasons(reasons)
        it.token = SecurityTokenizer.new_token unless PosRegistrationMatch.owners_pos_registration?(bike, pos_bike)
      end
      # The group may have been replaced since
      add_reasons(match, reasons, duplicate_bike_group_id:) unless match.previously_new_record?
      match
    end

    def add_reasons(match, reasons, **attributes)
      match.add_review_reasons!(reasons, **attributes) if match.pending?
    end
  end
end
