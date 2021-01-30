# frozen_string_literal: true

# A few things to make working with locations easier
# e.g. geocoder returns arrays and varies slightly depending on the provider
class Geohelper
  class << self
    def reverse_geocode(latitude, longitude)
      result = Geocoder.search([latitude, longitude])
      return nil unless result&.first
      result.first.formatted_address || result.first.address
    end

    # accept 'result' parameter to skip lookup for formatted_address_hash
    def coordinates_for(addy, result: nil)
      result ||= Geocoder.search(formatted_address(addy))
      return nil unless result&.any?
      geometry = result.first&.data && result.first.data["geometry"]
      if geometry && geometry["location"].present?
        location = geometry["location"]
      elsif geometry && geometry["bounds"].present?
        # Google returns a box that represents the area, return just one coordinate group from that box
        location = geometry["bounds"]["northeast"]
      elsif result.first&.data&.dig("latitude") # This is probably a test geocoder response...
        location = {"lat" => result.first.data["latitude"], "lng" => result.first.data["longitude"]}
      end
      return nil unless location
      {latitude: location["lat"], longitude: location["lng"]}
    end

    # Google isn't a fan of bare zipcodes anymore. But we search using bare zipcodes a lot - so make it work
    def formatted_address(addy)
      address = addy.to_s.strip
      address.match(/\A\d{5}\z/).present? ? "zipcode: #{address}" : address
    end

    def ignored_coordinates?(latitude, longitude)
      [
        [71.53880, -66.88542], # Google general can't find
        [37.09024, -95.71289] # USA can't find
      ].any? { |coord| coord[0] == latitude.round(5) && coord[1] == longitude.round(5) }
    end

    # TODO: location refactor - make this return the updated location attrs
    # Given a string, return a address hash for that location
    def formatted_address_hash(addy)
      result = Geocoder.search(formatted_address(addy))
      return {} if result&.first&.formatted_address.blank?
      coordinates = coordinates_for(addy, result: result)
      return {} if ignored_coordinates?(coordinates[:latitude], coordinates[:longitude])
      address_hash_from_geocoder_string(result&.first&.formatted_address)
        .merge(coordinates.present? ? coordinates : {})
    end

    def assignable_address_hash(addy)
      addy_hash = formatted_address_hash(addy)
      { street: addy_hash["street"],
        city: addy_hash["city"],
        zipcode: addy_hash["zipcode"],
        country: Country.fuzzy_find(addy_hash["country"]),
        state: State.fuzzy_find(addy_hash["state"]),
        latitude: addy_hash["latitude"],
        longitude: addy_hash["longitude"] }
    end

    def address_hash_from_geocoder_string(addy)
      address_array = addy.split(",").map(&:strip)
      country = address_array.pop # Don't care about this rn
      code_and_state = address_array.pop
      return {} if code_and_state.blank?
      state, code = code_and_state.split(" ") # In case it's a full zipcode with a dash
      city = address_array.pop
      {
        street: address_array.join(", "),
        city: city,
        state: state,
        zipcode: code,
        country: country&.gsub("USA", "US")
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
        zipcode: result.postal_code
      }
    end
  end
end
