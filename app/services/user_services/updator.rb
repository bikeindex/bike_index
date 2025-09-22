class UserServices::Updator
  class << self
    def assign_address_from_bikes(user, bikes: nil, save_user: false)
      bikes ||= user.bikes
      address_bike = bikes.with_street.first || bikes.with_location.first
      if address_bike.present?
        address_record = user.address_record ||
          AddressRecord.new(user_id: user.id, kind: :user, skip_geocoding: true, skip_callback_job: true)
        address_record.update(AddressRecord.attrs_from_legacy(address_bike))
        user.attributes = {
          address_record_id: address_record.id,
          latitude: address_record.latitude,
          longitude: address_record.longitude,
          address_set_manually: address_bike.address_set_manually
        }
        user.save if save_user
      end
      user
    end
  end
end
