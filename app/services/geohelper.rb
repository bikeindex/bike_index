# frozen_string_literal: true

# A few things to make working with locations easier
# e.g. geocoder returns arrays and varies slightly depending on the provider
class Geohelper
  class << self
    def reverse_geocode(latitude, longitude)
      result = Geocoder.search([latitude, longitude])
      return nil unless result&.first
       if Geocoder.config.lookup == :mapbox
        # the Mapbox result for address doesn't include the street number, so try to grab it from the data
        result.first.data["place_name"] || result.first.address
      else
        result.first.formatted_address || result.first.address
      end
    end

    # accept 'result' parameter to skip lookup for formatted_address_hash
    def coordinates_for(addy, result: nil)
      result ||= Geocoder.search(formatted_address(addy))
      return nil unless result&.any?
      if Geocoder.config.lookup == :mapbox
        # Mapbox specific work
        coords = result.first.coordinates
        return { latitude: coords[0], longitude: coords[1] }
      end
      geometry = result.first&.data && result.first.data["geometry"]
      if geometry && geometry["location"].present?
        location = geometry["location"]
      elsif geometry && geometry["bounds"].present?
        # Google returns a box that represents the area, return just one coordinate group from that box
        location = geometry["bounds"]["northeast"]
      elsif result.first&.data&.dig("latitude") # This is probably a test geocoder response...
        location = { "lat" => result.first.data["latitude"], "lng" => result.first.data["longitude"] }
      end
      return nil unless location
      { latitude: location["lat"], longitude: location["lng"] }
    end

    # Google isn't a fan of bare zipcodes anymore. But we search using bare zipcodes a lot - so make it work
    def formatted_address(addy)
      address = addy.to_s.strip
      address.match(/\A\d{5}\z/).present? ? "zipcode: #{address}" : address
    end

    # TODO: location refactor - make this return the updated location attrs
    # Given a string, return a address hash for that location
    def formatted_address_hash(addy)
      result = Geocoder.search(formatted_address(addy))
      return nil unless result&.first&.formatted_address.present?
      coordinates = coordinates_for(addy, result: result)
      address_hash_from_geocoder_string(result&.first&.formatted_address)
        .merge(coordinates.present? ? coordinates : {})
    end

    def address_hash_from_geocoder_string(addy)
      address_array = addy.split(",").map(&:strip)
      country = address_array.pop # Don't care about this rn
      code_and_state = address_array.pop
      state, code = code_and_state.split(" ") # In case it's a full zipcode with a dash
      city = address_array.pop
      {
        street: address_array.join(", "),
        city: city,
        state: state,
        zipcode: code,
        country: country&.gsub("USA", "US"),
      }.with_indifferent_access
    end

    def address_hash_from_geocoder_result(result)
      return {} if result.blank?
      {
        city: result.city,
        latitude: result.latitude,
        longitude: result.longitude,
        state_id: State.fuzzy_find(result.state_code)&.id,
        country_id: Country.fuzzy_find(result.country_code)&.id,
        zipcode: result.postal_code,
      }
    end
  end
end
