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
      :registry_name,
      :registry_url,
      :source_name,
      :source_unique_id,
      :url

    def initialize(json)
      self.json = json
      self.registry_name = "stopheling.nl"
      self.registry_url = "https://www.stopheling.nl"
      self.url = registry_url
      self.brand = json[:brand].presence
      self.brand_type = json[:brand_type].presence
      self.category = json[:category].presence
      self.date_found = json[:insert_date]&.in_time_zone("UTC")
      self.frame_color = json[:color].presence
      self.object = json[:object].presence
      self.registry_id = json[:registration_number].presence
      self.license_plate_number = json[:license_plate_number].presence
      self.chassis_number = json[:chassis_number].presence
      self.source_name = json[:source_name].presence
      self.source_unique_id = json[:source_unique_id].presence
      self.location = parse_location(json[:source_name])
    end

    def bike?
      object.match?(/fiets/i)
    end

    def serial_number
      chassis_number || license_plate_number || "absent"
    end

    def to_external_bike
      attrs = {}.tap do |h|
        h[:registry_name] = registry_name
        h[:registry_id] = registry_id
        h[:registry_url] = registry_url
        h[:url] = url
        h[:type] = "bike"
        h[:status] = "stolen"
        h[:mnfg_name] = brand
        h[:frame_model] = brand_type
        h[:location_found] = location
        h[:frame_colors] = colors
        h[:date_stolen] = date_found
        h[:serial_number] = serial_number
        h[:debug] = json.map { |e| e.join(": ") }.join("\n")
        h[:source_name] = source_name
        h[:source_unique_id] = source_unique_id
      end

      ExternalRegistries::ExternalBike.new(**attrs)
    end

    private

    def colors
      return ["Unknown"] if absent?(frame_color)
      [frame_color]
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
