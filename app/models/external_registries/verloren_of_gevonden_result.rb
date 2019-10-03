module ExternalRegistries
  class VerlorenOfGevondenResult
    attr_accessor \
      :json,
      :registry_name,
      :registry_url,
      :category,
      :city,
      :color,
      :country,
      :description,
      :form_link,
      :object_id,
      :object_number,
      :organization_name,
      :registration_date,
      :storage_location,
      :subcategory,
      :date_found,
      :location_found,
      :serial_number

    def initialize(json)
      self.json = json
      self.registry_name = "verlorenofgevonden.nl"
      self.registry_url = "https://#{registry_name}"

      self.category = json["Category"].presence
      self.city = json["City"].presence
      self.color = json["Color"].presence
      self.country = json["Country"].presence
      self.description = json["Description"].presence
      self.form_link = json["FormLink"].presence
      self.object_id = json["ObjectId"].presence
      self.object_number = json["ObjectNumber"].presence
      self.organization_name = json["OrganisationName"].presence
      self.registration_date = json["RegistrationDate"].presence
      self.storage_location = json["StorageLocation"].presence
      self.subcategory = json["SubCategory"].presence

      self.date_found = parse_date_found
      self.location_found = parse_location_found
      self.serial_number = parse_serial_number
    end

    def brand
      brand_name = json["Brand"]
      return "Unknown Brand" if absent?(brand_name)
      brand_name
    end

    def bike?
      category == "fiets"
    end

    def image_url
      "#{self.registry_url}/assets/image/#{object_id}"
    end

    def url
      "#{registry_url}/overzicht?search=#{object_number}"
    end

    def to_external_bike
      attrs = {}.tap do |h|
        h[:type] = "bike"
        h[:status] = "abandoned"
        h[:registry_name] = registry_name
        h[:registry_id] = object_number
        h[:registry_url] = registry_url
        h[:url] = url
        h[:thumb_url] = image_url
        h[:image_url] = image_url
        h[:mnfg_name] = brand
        h[:frame_model] = subcategory
        h[:frame_colors] = colors
        h[:date_stolen] = date_found
        h[:serial_number] = serial_number
        h[:location_found] = [location_found, country].join(", ")
        h[:description] = description
        h[:debug] = json.map { |e| e.join(": ") }.join("\n")
      end

      ExternalRegistries::ExternalBike.new(**attrs)
    end

    def colors
      return ["Unknown"] if absent?(color)
      [color]
    end

    private

    def absent?(value)
      value.presence.blank? ||
        value.match?(/geen|onbekend/i)
    end

    DATE_REGEX = %r{overgebracht .+ op (?<day>\d{1,2})-(?<month>\d{1,2})-(?<year>\d{4})}

    def parse_date_found
      match_data = DATE_REGEX.match(description)
      return registration_date.in_time_zone("UTC") unless match_data

      %i[year month day]
        .map { |m| match_data[m] }
        .join("-")
        .in_time_zone("UTC")
    end

    LOCATION_REGEX = %r{Locatie gevonden: (.+?)\.}

    def parse_location_found
      match_data = LOCATION_REGEX.match(description)
      return match_data[1] if match_data
      return storage_location if storage_location.is_a?(String)

      %w[Name City]
        .map { |key| storage_location[key].presence }
        .compact
        .join(",")
    end

    SERIAL_NUMBER_REGEX = %r{framenummer '(?:<strong>)?(.+)(?:</strong>)?'}

    def parse_serial_number
      match_data = SERIAL_NUMBER_REGEX.match(description)
      return "absent" if match_data.blank? || absent?(match_data[1])
      match_data[1]
    end
  end
end
