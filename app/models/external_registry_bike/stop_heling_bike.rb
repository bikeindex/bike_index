# == Schema Information
#
# Table name: external_registry_bikes
# Database name: primary
#
#  id                        :integer          not null, primary key
#  category                  :string
#  cycle_type                :string
#  date_stolen               :datetime
#  description               :string
#  external_updated_at       :datetime
#  extra_registration_number :string
#  frame_colors              :string
#  frame_model               :string
#  info_hash                 :jsonb
#  location_found            :string
#  mnfg_name                 :string
#  serial_normalized         :string           not null
#  serial_number             :string           not null
#  status                    :integer
#  type                      :string           not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  country_id                :integer          not null
#  external_id               :string           not null
#
# Indexes
#
#  index_external_registry_bikes_on_country_id         (country_id)
#  index_external_registry_bikes_on_external_id        (external_id)
#  index_external_registry_bikes_on_serial_normalized  (serial_normalized)
#  index_external_registry_bikes_on_type               (type)
#
class ExternalRegistryBike::StopHelingBike < ExternalRegistryBike
  def registry_url
    "https://www.stopheling.nl"
  end

  def url
    registry_url
  end

  class << self
    def build_from_api_response(attrs = {})
      is_bike = attrs[:object]&.match?(/fiets/i)
      return unless is_bike

      bike = find_or_initialize_by(
        external_id: attrs[:registration_number].presence,
        serial_number: serial_number(attrs),
        type: to_s
      )

      bike.cycle_type = "bike"
      bike.status = "status_stolen" # No need for converter, they all come in as stolen
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
        country_iso
      ].select(&:present?).join(" - ")
    end
  end
end
