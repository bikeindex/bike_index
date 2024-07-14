# frozen_string_literal: true

# A few things to make working with locations easier
# e.g. geocoder returns arrays and varies slightly depending on the provider
class Geohelper
  class << self
    # Always returns latitude and longitude
    def coordinates_for(lookup_string)
      coords = geocoder_search(lookup_string).slice(:latitude, :longitude)
      coords.present? ? coords : {latitude: nil, longitude: nil}
    end

    def address_string_for(lookup_string)
      geocoder_search(lookup_string).slice(:formatted_address)
    end

    def bounding_box(lookup_string, distance)
      box = Geocoder::Calculations.bounding_box(geocoder_lookup_string(lookup_string), distance)
      box.detect(&:nan?) ? [] : box
    end

    def assignable_address_hash_for(lookup_string = nil, latitude: nil, longitude: nil)
      address_hash = if latitude.present? && longitude.present?
        address_hash_from_reverse_geocode(latitude, longitude)
          .merge(latitude: latitude, longitude: longitude) # keep original coordinates!
      else
        geocoder_search(lookup_string)
      end

      assignable_address_hash(address_hash)
    end

    private

    def geocoder_search(lookup_string)
      address_hash_from_geocoder_result(
        Geocoder.search(geocoder_lookup_string(lookup_string))
      )
    end

    def assignable_address_hash(address_hash)
      address_hash.except(:formatted_address)
    end

    # # TODO: location refactor - make this return the updated location attrs
    # # Given a string, return an address hash for that location
    # def formatted_address_hash(addy)
    #   result = Geocoder.search(formatted_address(addy))
    #   return {} if result&.first&.formatted_address.blank?
    #   coordinates = coordinates_for(addy, result: result)
    #   return {} if ignored_coordinates?(coordinates[:latitude], coordinates[:longitude])
    #   address_hash_from_geocoder_string(result&.first&.formatted_address)
    #     .merge(coordinates.present? ? coordinates : {})
    # end

    # def address_hash_from_geocoder_string(addy)
    #   address_array = addy.split(",").map(&:strip)
    #   country = address_array.pop # Don't care about this rn
    #   code_and_state = address_array.pop
    #   return {} if code_and_state.blank?
    #   state, code = code_and_state.split(" ") # In case it's a full zipcode with a dash
    #   city = address_array.pop
    #   {
    #     street: address_array.join(", "),
    #     city: city,
    #     state: state,
    #     zipcode: code,
    #     country: country&.gsub("USA", "US")
    #   }.with_indifferent_access
    # end

    # Google isn't a fan of bare zipcodes anymore. But we search using bare US zipcodes a lot - so make it work
    def geocoder_lookup_string(addy)
      address = addy.to_s.strip
      address.match(/\A\d{5}\z/).present? ? "zipcode: #{address}" : address
    end

    def ignored_coordinates?(latitude, longitude)
      [
        [71.53880, -66.88542], # Google general can't find
        [37.09024, -95.71289] # USA can't find
      ].any? { |coord| coord[0] == latitude.round(5) && coord[1] == longitude.round(5) }
    end

    def address_hash_from_reverse_geocode(latitude, longitude)
      address_hash_from_geocoder_result(Geocoder.search([latitude, longitude]))
    end

    # result ||= Geocoder.search(formatted_address(addy))
    # return nil unless result&.any?
    # geometry = result.first&.data && result.first.data["geometry"]
    # if geometry && geometry["location"].present?
    #   location = geometry["location"]
    # elsif geometry && geometry["bounds"].present?
    #   # Google returns a box that represents the area, return just one coordinate group from that box
    #   location = geometry["bounds"]["northeast"]
    # elsif result.first&.data&.dig("latitude") # This is probably a test geocoder response...
    #   location = {"lat" => result.first.data["latitude"], "lng" => result.first.data["longitude"]}
    # end
    # return nil unless location
    # {latitude: location["lat"], longitude: location["lng"]}

    def address_hash_from_geocoder_result(results)
      return {} unless results&.first.present?
      result = results.first # Maybe someday use multiple results? Not a priority
      address_hash = if defined?(result.city)
        hash_for_google_response(result)
      elsif defined?(result.data["geometry"]) && result.data["geometry"]["bounds"].present?
        # Google returned a box that represents the area, return just one coordinate group from that box
        coordinates_from_google_response(result.data.dig("geometry", "bounds", "northeast"))
      else
        {failed: result}
      end
      # pp results, address_hash
      ignored_coordinates?(address_hash[:latitude], address_hash[:longitude]) ? {} : address_hash
    end

    def hash_for_google_response(result)
      {
        city: result.city,
        latitude: result.latitude,
        longitude: result.longitude,
        formatted_address: result.formatted_address,
        state_id: State.friendly_find(result.state_code)&.id,
        country_id: Country.friendly_find(result.country_code)&.id,
        neighborhood: result.neighborhood,
        street: result.street_address,
        zipcode: result.postal_code
      }
    end

    def coordinates_from_google_response(coord_hash)
      { latitude: coord_hash["lat"], longitude: coord_hash["lng"] }
    end
  end
end
