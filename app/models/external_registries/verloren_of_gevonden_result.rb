module ExternalRegistries
  class VerlorenOfGevondenResult
    attr_accessor \
      :json,
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

    def external_registry
      ExternalRegistry.verloren_of_gevonden
    end

    def registry_name
      external_registry&.name
    end

    def registry_url
      external_registry&.url
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
      "#{self.registry_url}/images/pv_api/get_from_api.php?id=#{object_id}"
    end

    def url
      "#{registry_url}/overzicht?search=#{object_number}"
    end

    def to_external_registry_bike
      bike = ::ExternalRegistryBike.find_or_initialize_by(
        external_id: object_number,
        external_registry: external_registry,
        serial_number: serial_number,
      )

      bike.cycle_type = "bike"
      bike.status = "abandoned"
      bike.url = url
      bike.thumb_url = image_url
      bike.image_url = image_url
      bike.mnfg_name = brand
      bike.frame_model = subcategory
      bike.frame_colors = colors
      bike.date_stolen = date_found
      bike.location_found = location
      bike.description = description

      bike
    end

    def location
      [location_found, country]
        .select(&:present?)
        .map(&:titleize)
        .join(", ")
    end

    def colors
      return "Unknown" if absent?(color)
      color
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
        .map { |key| storage_location[key] }
        .select(&:present?)
        .join(", ")
    end

    SERIAL_NUMBER_REGEX = %r{framenummer '(?:<strong>)?(.+)(?:</strong>)?'}

    def parse_serial_number
      match_data = SERIAL_NUMBER_REGEX.match(description)
      return "absent" if match_data.blank? || absent?(match_data[1])
      match_data[1]
    end
  end
end
