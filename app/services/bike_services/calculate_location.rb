class BikeServices::CalculateLocation
  class << self
    def registration_address_source(bike)
      # NOTE: Marketplace Listing and User address are the preferred addresses!
      # If either is set, address fields don't show on bike!
      if bike.is_for_sale && bike.current_marketplace_listing.present?
        "marketplace_listing"
      elsif bike.user&.address_set_manually
        "user"
      elsif bike.address_set_manually
        "bike_update"
      elsif bike.current_ownership&.address_record?
        "initial_creation"
      end
    end

    def registration_address_record(bike)
      case registration_address_source(bike)
      when "marketplace_listing" then bike.current_marketplace_listing.address_record
      when "user" then bike.user&.address_record
      when "bike_update" then bike.address_record
      when "initial_creation" then bike.current_ownership.address_record
      end
    end

    def registration_address_hash(bike, address_record_id: false)
      (registration_address_record(bike)&.address_hash_legacy(address_record_id:) || {})
        .with_indifferent_access
    end

    # Set the bike's location data (lat/long, city, postal code, country, etc.)
    #
    # Geolocate based on the full current stolen record address, if available.
    # Otherwise, use the data set by location_record_address_hash
    # Sets lat/long, will avoid a geocode API call if coordinates are found
    def stored_location_attrs(bike)
      if bike.current_stolen_record.present?
        # If there is a current stolen - even if it has a blank location - use it
        # It's used for searching and displaying stolen bikes, we don't want other information leaking
        bike.current_stolen_record.attributes.slice("latitude", "longitude")
      else
        attrs = {}
        # If address is comes from the user record, address_set_manually is no longer correct!
        if bike.address_set_manually && bike.user&.address_set_manually
          attrs[:address_set_manually] = false
        end
        attrs.merge(location_record_coordinates(bike))
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
    def location_record_coordinates(bike)
      l_hashes = [
        bike.current_impound_record&.address_hash_legacy,
        bike.current_parking_notification&.address_hash,
        bike.registration_address(true, address_record_id: true), # temporary cludge?
        bike.creation_organization&.default_location&.address_hash_legacy
      ].compact
      l_hash = l_hashes.find { |rec| rec&.dig("street").present? } ||
        l_hashes.find { |rec| rec&.dig("latitude").present? }
      return {} unless l_hash.present?

      # Only ever respond with the coordinates
      l_hash.slice("latitude", "longitude", "address_record_id")
    end
  end
end
