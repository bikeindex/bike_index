# frozen_string_literal: true

# A few things to make working with locations easier
# e.g. geocoder returns arrays and varies slightly depending on the provider
class GeocodeHelper
  MIN_DISTANCE = 1
  MAX_DISTANCE = 1_000
  DEFAULT_DISTANCE = 100

  class << self
    # Always returns latitude and longitude
    def coordinates_for(lookup_string)
      coords = assignable_address_hash_for(lookup_string).slice(:latitude, :longitude)
      coords.present? ? coords : {latitude: nil, longitude: nil}
    end

    def address_string_for(lookup_string)
      address_hash_for(lookup_string).slice(:formatted_address)
    end

    def permitted_distance(distance = nil, default_distance: DEFAULT_DISTANCE)
      return default_distance if distance.blank? || (distance.is_a?(String) && !distance.match?(/\d/))

      clamped_distance = distance.to_f.clamp(MIN_DISTANCE, MAX_DISTANCE)
      (clamped_distance % 1 == 0) ? clamped_distance.to_i : clamped_distance
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

    def address_hash_for(lookup_string, new_attrs: false)
      address_hash_from_geocoder_result(
        Geocoder.search(geocoder_lookup_string(lookup_string)), new_attrs:
      )
    end

    # assignable_address_hash is just the address hash without the "formatted_address" string
    def assignable_address_hash_for(lookup_string = nil, latitude: nil, longitude: nil, new_attrs: false)
      address_hash = if latitude.present? && longitude.present?
        address_hash_from_reverse_geocode(latitude, longitude, new_attrs:)
          .merge(latitude: latitude, longitude: longitude) # keep original coordinates!
      else
        address_hash_for(lookup_string, new_attrs:)
      end

      address_hash.except(:formatted_address)
    end

    private

    # Google isn't a fan of bare zipcodes anymore. But we search using bare US zipcodes a lot - so make it work
    def geocoder_lookup_string(addy)
      address = addy.to_s.strip
      address.match(/\A\d{5}\z/).present? ? "zipcode: #{address}" : address
    end

    def ignored_coordinates?(latitude, longitude)
      return true if latitude.blank?
      [
        [71.53880, -66.88542], # Google general can't find
        [37.09024, -95.71289], # USA can't find
        [37.751, -97.822], # USA can't find
        [38.79460, -106.53484] # USA can't find also
      ].any? { |coord| coord[0] == latitude.round(5) && coord[1] == longitude.round(5) }
    end

    def address_hash_from_reverse_geocode(latitude, longitude, new_attrs:)
      address_hash_from_geocoder_result(Geocoder.search([latitude, longitude]), new_attrs:)
    end

    def address_hash_from_geocoder_result(results, new_attrs:)
      return {} unless results&.first.present?
      result = results.first # Maybe someday use multiple results? Not a priority
      address_hash = if result.respond_to?(:city)
        hash_for_geocoder_response(result, new_attrs:)
      elsif defined?(result.data["geometry"]) && result.data["geometry"]["bounds"].present?
        # Google returned a box that represents the area, return just one coordinate group from that box
        coordinates_from_google_response(result.data.dig("geometry", "bounds", "northeast"))
      else
        {}
      end
      return {} if ignored_coordinates?(address_hash[:latitude], address_hash[:longitude])
      address_hash.transform_values { |v| v.blank? ? nil : v }
    end

    def hash_for_geocoder_response(result, new_attrs:)
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

      postal_and_region = if new_attrs
        {
          postal_code: result.postal_code,
          region_string: result.state_code
        }
      else
        {
          state_id: State.friendly_find(result.state_code)&.id, # TODO: Use region_code instead
          zipcode: result.postal_code
        }
      end

      {
        city: result.city,
        latitude: result.latitude,
        longitude: result.longitude,
        formatted_address: formatted_address&.gsub(" ,", ","), # something is broken and causes bad spacing from maxmind - fix it here
        country_id: Country.friendly_find(result.country_code)&.id,
        neighborhood: result.respond_to?(:neighborhood) ? result.neighborhood : nil,
        street: street
      }.merge(postal_and_region)
    end

    def coordinates_from_google_response(coord_hash)
      {latitude: coord_hash["lat"], longitude: coord_hash["lng"]}
    end
  end
end
