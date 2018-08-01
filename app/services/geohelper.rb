class Geohelper
  class << self
    def reverse_geocode(latitude, longitude)
      result = Geocoder.search([latitude, longitude])
      return nil unless result && result.first
      result.first.formatted_address || result.first.address
    end
  end
end
