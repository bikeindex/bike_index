# frozen_string_literal: true

# A few things to make working with locations easier
# e.g. geocoder returns arrays and varies slightly depending on the provider
class GeocodeHelper
  class << self
    # Always returns latitude and longitude
    def coordinates_for(lookup_string)
      coords = address_hash_for(lookup_string).slice(:latitude, :longitude)
      coords.present? ? coords : {latitude: nil, longitude: nil}
    end

    def address_string_for(lookup_string)
      address_hash_for(lookup_string).slice(:formatted_address)
    end

    def bounding_box(lookup_string, distance)
      box_param = if lookup_string.is_a?(Array) && lookup_string.length == 2
        lookup_string # It's a coordinate array, use it (rather than doing a lookup)
      else
        geocoder_lookup_string(lookup_string)
      end
      box_coords = Geocoder::Calculations.bounding_box(box_param, distance)
      box_coords.detect(&:nan?) ? [] : box_coords
    end

    def assignable_address_hash_for(lookup_string = nil, latitude: nil, longitude: nil)
      address_hash = if latitude.present? && longitude.present?
        address_hash_from_reverse_geocode(latitude, longitude)
          .merge(latitude: latitude, longitude: longitude) # keep original coordinates!
      else
        address_hash_for(lookup_string)
      end

      assignable_address_hash(address_hash)
    end

    def address_hash_for(lookup_string)
      address_hash_from_geocoder_result(
        Geocoder.search(geocoder_lookup_string(lookup_string))
      )
    end

    private

    def assignable_address_hash(address_hash)
      address_hash.except(:formatted_address)
    end

    # Google isn't a fan of bare zipcodes anymore. But we search using bare US zipcodes a lot - so make it work
    def geocoder_lookup_string(addy)
      address = addy.to_s.strip
      address.match(/\A\d{5}\z/).present? ? "zipcode: #{address}" : address
    end

    def ignored_coordinates?(latitude, longitude)
      return true if latitude.blank?
      [
        [71.53880, -66.88542], # Google general can't find
        [37.09024, -95.71289] # USA can't find
      ].any? { |coord| coord[0] == latitude.round(5) && coord[1] == longitude.round(5) }
    end

    def address_hash_from_reverse_geocode(latitude, longitude)
      address_hash_from_geocoder_result(Geocoder.search([latitude, longitude]))
    end

    def address_hash_from_geocoder_result(results)
      return {} unless results&.first.present?
      result = results.first # Maybe someday use multiple results? Not a priority
      address_hash = if result.respond_to?(:city)
        hash_for_geocoder_response(result)
      elsif defined?(result.data["geometry"]) && result.data["geometry"]["bounds"].present?
        # Google returned a box that represents the area, return just one coordinate group from that box
        coordinates_from_google_response(result.data.dig("geometry", "bounds", "northeast"))
      else
        {}
      end
      return {} if ignored_coordinates?(address_hash[:latitude], address_hash[:longitude])
      address_hash.transform_values { |v| v.blank? ? nil : v }
    end

    def hash_for_geocoder_response(result)
      # Google has street_address - use it if possible
      street = if result.respond_to?(:street_address)
        result.street_address
      elsif result.respond_to?(:street)
        result.street
      end
      # Google has formatted_address
      formatted_address = if result.respond_to?(:formatted_address)
        result.formatted_address
      else
        result.address
      end
      {
        city: result.city,
        latitude: result.latitude,
        longitude: result.longitude,
        formatted_address: formatted_address,
        state_id: State.friendly_find(result.state_code)&.id, # TODO: Use region_code instead
        country_id: Country.friendly_find(result.country_code)&.id,
        neighborhood: result.respond_to?(:neighborhood) ? result.neighborhood : nil,
        street: street,
        zipcode: result.postal_code
      }
    end

    def coordinates_from_google_response(coord_hash)
      {latitude: coord_hash["lat"], longitude: coord_hash["lng"]}
    end
  end
end
