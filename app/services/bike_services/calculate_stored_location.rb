class BikeServices::CalculateStoredLocation
  class << self
    # Set the bike's location data (lat/long, city, postal code, country, etc.)
    #
    # Geolocate based on the full current stolen record address, if available.
    # Otherwise, use the data set by location_record_address_hash
    # Sets lat/long, will avoid a geocode API call if coordinates are found
    def location_attrs(bike)
      if bike.current_stolen_record.present?
        # If there is a current stolen - even if it has a blank location - use it
        # It's used for searching and displaying stolen bikes, we don't want other information leaking
        if bike.address_set_manually # Only set coordinates if the address is set manually
          bike.current_stolen_record.attributes.slice("latitude", "longitude")
        else # Set the whole address from the stolen record
          bike.current_stolen_record.address_hash
        end
      else
        attrs = {}
        if bike.address_set_manually # If it's not stolen, use the manual set address for the coordinates
          return {} unless bike.user&.address_set_manually # If it's set by the user, address_set_manually is no longer correct!

          attrs[:address_set_manually] = false
        end
        attrs.merge(location_record_address_hash(bike))
      end
    end

    private

    # Select the source from which to derive location data, in the following order
    # of precedence:
    #
    # 1. The current parking notification/impound record, if one is present
    # 2. #registration_address (which prioritizes user address)
    # 3. The creation organization address (so we have a general area for the bike)
    # prefer with street address, fallback to anything with a latitude, use hashes (not obj) because registration_address
    def location_record_address_hash(bike)
      l_hashes = [
        bike.current_impound_record&.address_hash,
        bike.current_parking_notification&.address_hash,
        bike.registration_address(true),
        bike.creation_organization&.default_location&.address_hash
      ].compact
      l_hash = l_hashes.find { |rec| rec&.dig("street").present? } ||
        l_hashes.find { |rec| rec&.dig("latitude").present? }
      return {} unless l_hash.present?

      # If the location record has coordinates, skip geocoding
      l_hash.merge(skip_geocoding: l_hash["latitude"].present?)
    end
  end
end
