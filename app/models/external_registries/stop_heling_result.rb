module ExternalRegistries
  class StopHelingResult
    attr_accessor \
      :json,
      :brand,
      :brand_type,
      :category,
      :chassis_number,
      :date_found,
      :frame_color,
      :license_plate_number,
      :location,
      :object,
      :registry_id,
      :source_name,
      :source_unique_id

    def initialize(json)
      self.json = json
      self.brand = json[:brand].presence
      self.brand_type = json[:brand_type].presence
      self.category = json[:category].presence
      self.date_found = json[:insert_date]
      self.frame_color = json[:color].presence
      self.object = json[:object].presence
      self.registry_id = json[:registration_number].presence
      self.license_plate_number = json[:license_plate_number].presence
      self.chassis_number = json[:chassis_number].presence
      self.source_name = json[:source_name].presence
      self.source_unique_id = json[:source_unique_id].presence
      self.location = parse_location(json[:source_name])
    end

    def external_registry
      ExternalRegistry.stop_heling
    end

    def registry_name
      external_registry&.name
    end

    def registry_url
      external_registry&.url
    end

    def url
      registry_url
    end

    def bike?
      object.match?(/fiets/i)
    end

    def serial_number
      chassis_number || license_plate_number || "absent"
    end

    def to_external_registry_bike
      bike = ::ExternalRegistryBike.find_or_initialize_by(
        external_id: registry_id,
        external_registry: external_registry,
        serial_number: serial_number,
      )

      bike.url = url
      bike.cycle_type = "bike"
      bike.status = "stolen"
      bike.mnfg_name = brand
      bike.frame_model = brand_type
      bike.location_found = location
      bike.frame_colors = colors
      bike.date_stolen = date_found.to_datetime
      bike.source_name = source_name
      bike.source_unique_id = source_unique_id

      bike
    end

    private

    def colors
      return "Unknown" if absent?(frame_color)
      frame_color
    end

    def absent?(value)
      value.presence.blank? ||
        value.match?(/geen|onbekend/i)
    end

    def parse_location(source_name)
      return if source_name.blank?

      [source_name.sub(/politie/i, "").strip, "Nederland"]
        .select(&:present?)
        .map(&:titleize)
        .join(", ")
    end
  end
end
