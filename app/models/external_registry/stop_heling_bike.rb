module ExternalRegistry
  class StopHelingBike < ExternalRegistryBike
    def external_registry_name
      "stopheling.nl"
    end

    def external_registry_url
      "https://www.stopheling.nl"
    end

    def url
      external_registry_url
    end

    class << self
      def build_from_api_response(attrs = {})
        is_bike = attrs[:object]&.match?(/fiets/i)
        return unless is_bike

        bike = find_or_initialize_by(
          external_id: attrs[:registration_number].presence,
          type: "ExternalRegistry::StopHelingBike",
          serial_number: serial_number(attrs),
        )

        bike.cycle_type = "bike"
        bike.status = "stolen"
        bike.country = Country.netherlands

        bike.frame_colors = colors(attrs[:color])
        bike.location_found = parse_location(attrs[:source_name], bike.country.iso)

        bike.date_stolen = attrs[:insert_date].to_datetime
        bike.frame_model = attrs[:brand_type].presence
        bike.mnfg_name = attrs[:brand].presence

        bike
      end

      private

      def serial_number(attrs)
        attrs[:chassis_number].presence ||
          attrs[:license_plate_number].presence ||
          "absent"
      end

      def parse_location(source_name, country_iso)
        return if source_name.blank?

        [
          source_name.sub(/politie/i, "").strip&.titleize,
          country_iso,
        ].select(&:present?).join(" - ")
      end
    end
  end
end
