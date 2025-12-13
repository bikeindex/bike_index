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
class ExternalRegistryBike::Project529Bike < ExternalRegistryBike
  def registry_url
    "https://project529.com"
  end

  def url
    info_hash["url"]
  end

  def image_url
    info_hash["image_url"]
  end

  def thumb_url
    info_hash["thumb_url"]
  end

  class << self
    def updated_since_date
      [
        maximum(:external_updated_at) || Time.current - 3.years,
        Time.current - 1.day
      ].min
    end

    def build_from_api_response(attrs = {})
      return if attrs["status"]&.downcase == "recovered"

      bike = find_or_initialize_by(
        external_id: attrs["id"],
        serial_number: attrs["serial_number"],
        type: to_s
      )

      bike.cycle_type = "bike"
      bike.status = ExternalRegistryBike.status_converter(attrs["status"])
      bike.frame_model = attrs["model_string"]
      bike.mnfg_name = attrs["manufacturer_string"]
      bike.location_found = attrs.dig("active_incident", "location_address")
      bike.frame_colors = frame_colors(attrs)
      bike.description = description(attrs)
      bike.date_stolen = StolenRecord.corrected_date_stolen(date_stolen(attrs))
      bike.country = country(attrs)
      bike.info_hash = info_hash(attrs)
      bike.external_updated_at = Binxtils::TimeParser.parse(attrs["updated_at"])

      bike
    end

    private

    def info_hash(attrs)
      photo = primary_photo(attrs)

      {
        url: attrs["url"],
        image_url: photo["original_url"],
        thumb_url: photo["medium_url"]
      }
    end

    def country(attrs)
      name = attrs.dig("active_incident", "location_address")&.split(",")&.last
      Country.friendly_find(name)
    end

    def frame_colors(attrs)
      %w[primary_color secondary_color]
        .map { |key| attrs[key] }
        .select(&:present?)
        .join(", ")
    end

    def description(attrs)
      attrs["description"].presence ||
        %w[model_year manufacturer_string model_string]
          .map { |key| attrs[key] }
          .select(&:present?)
          .join(" ")
    end

    def date_stolen(attrs)
      attrs.dig("active_incident", "last_seen").presence ||
        attrs.dig("active_incident", "created_at")
    end

    def primary_photo(attrs)
      all_photos =
        attrs["bike_photos"]
          .to_a
          .group_by { |ph| ph["photo_type"] }
          .map { |photo_type, photos| [photo_type.downcase, photos.first] }
          .reject { |photo_type, _photos| photo_type.in?(["serial number", "shield"]) }
          .to_h

      photo =
        all_photos["side"] ||
        all_photos["what to look for"] ||
        all_photos.values.flatten.first

      photo || {}
    end
  end
end
