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

    def coordinates_for(address)
      geometry = Geocoder.search(address)&.first&.data["geometry"]
      if geometry && geometry["location"].present?
        location = geometry["location"]
      elsif geometry && geometry["bounds"].present?
        # Google returns a box that represents the area, return just one coordinate group from that box
        location = geometry["bounds"]["northeast"]
      end
      return nil unless location
      { latitude: location["lat"], longitude: location["lng"] }
    end
  end
end
