class UserServices::Updator
  class << self
    def assign_address_from_bikes(user, bikes: nil, save_user: false)
      bikes ||= user.bikes
      address_bike = bikes.with_street.first || bikes.with_location.first
      return if address_bike.blank?

      address_record = user.address_record || AddressRecord.new
      address_record.update(
        AddressRecord.attrs_to_duplicate(address_bike).merge(user_id: user.id, kind: :user)
      )
      if address_bike.address_record.blank?
        # TODO: I think this can be removed once bike address migration finishes - #2922
        address_bike.update(address_record_id: address_record.id)
      elsif address_bike.address_record? && address_bike.address_record.user_id.blank?
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
  end
end
