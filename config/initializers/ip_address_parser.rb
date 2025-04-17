class IpAddressParser
  class << self
    def forwarded_address(request)
      addy = request.env["HTTP_CF_CONNECTING_IP"]
      addy ||= request.env["HTTP_X_FORWARDED_FOR"].split(",").last if request.env["HTTP_X_FORWARDED_FOR"].present?
      addy || request.env["REMOTE_ADDR"] || request.env["ip"]
    end

    def location_hash(request)
      # Additional CF headers that we're ignoring: timezone, continent, region-code, and metro-code
      {
        city: request.env["HTTP_CF_IPCITY"],
        latitude: request.env["HTTP_CF_IPLATITUDE"],
        longitude: request.env["HTTP_CF_IPLONGITUDE"],
        formatted_address: nil, # could build this, ignoring for now
        country_id: Country.friendly_find_id(request.env["HTTP_CF_IPCOUNTRY"]),
        neighborhood: request.env["HTTP_CF_METRO"],
        street: nil,
        postal_code: request.env["HTTP_CF_POSTAL_CODE"],
        region_string: request.env["HTTP_CF_REGION"]
      }
    end

    def location_hash_geocoder(ip_address, new_attrs: false)
      GeocodeHelper.address_hash_for(ip_address, new_attrs:)
    end
  end
end
