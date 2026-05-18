module UserServices
  class Updator
    class << self
      def assign_address_from_bikes(user, bikes: nil, save_user: false)
        bikes ||= bikes_for_user(user)
        address_bike = bikes.with_street.first || bikes.with_location.first
        return if address_bike.blank?

        address_record = user.address_record || AddressRecord.new
        address_record.update(
          Geocodeable.attrs_to_duplicate(address_bike).merge(user_id: user.id, kind: :user)
        )
        if address_bike.address_record? && address_bike.address_record.user_id.blank?
          address_bike.address_record.update(user_id: user.id)
        end
        user.attributes = {
          address_record_id: address_record.id,
          latitude: address_record.latitude,
          longitude: address_record.longitude,
          address_set_manually: address_bike.address_set_manually
        }
        user.update(skip_update: true) if save_user
        user
      end

      private

      # Skip user.bikes' default_includes — with_street's where.not + LIMIT 1
      # would otherwise force a 6-table LEFT JOIN to find one row.
      def bikes_for_user(user)
        Bike.unscoped.without_deleted.where(example: false)
          .joins(:current_ownership).where(ownerships: {user_id: user.id})
          .order(:id)
      end
    end
  end
end
