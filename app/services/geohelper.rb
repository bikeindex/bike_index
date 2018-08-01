class Geohelper
  class << self
    def reverse_geocode(latitude, longitude)
      result = Geocoder.search(latitude: latitude, longitude: longitude)
      result && result.first && result.first.formatted_address
    end
  end
end
