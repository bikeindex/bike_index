# == Schema Information
#
# Table name: external_registry_bikes
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
class ExternalRegistryBike::VerlorenOfGevondenBike < ExternalRegistryBike
  def registry_url
    "https://verlorenofgevonden.nl"
  end

  def url
    [registry_url, "overzicht?search=#{external_id}"].join("/")
  end

  def image_url
    return if info_hash["object_id"].blank?
    [registry_url, "assets", "image", info_hash["object_id"]].join("/")
  end

  def thumb_url
    image_url
  end

  class << self
    def build_from_api_response(attrs = {})
      is_bike = attrs["Category"] == "fiets"
      return unless is_bike

      description = attrs["Description"].presence

      bike = find_or_initialize_by(
        external_id: attrs["ObjectNumber"].presence,
        serial_number: parse_serial_number(description),
        type: to_s
      )

      bike.cycle_type = "bike"
      bike.status = "status_impounded" # No need for converter, they all come in as abandoned
      bike.country = Country.netherlands
      bike.description = description
      bike.frame_model = attrs["SubCategory"].presence
      bike.date_stolen = parse_date_found(description, attrs["RegistrationDate"].presence)
      bike.mnfg_name = brand(attrs["Brand"].presence)
      bike.frame_colors = colors(attrs["Color"].presence)
      bike.info_hash = {object_id: attrs["ObjectId"]}

      bike.location_found = [
        parse_location_found(description, attrs["StorageLocation"]),
        bike.country.iso
      ].select(&:present?).join(" - ")

      bike
    end

    def impounded_kind
      ImpoundRecord.impounded_kind
    end

    private

    DATE_REGEX = %r{overgebracht .+ op (?<day>\d{1,2})-(?<month>\d{1,2})-(?<year>\d{4})}

    def parse_date_found(description, registration_date)
      match_data = DATE_REGEX.match(description)
      return registration_date.to_datetime if registration_date && !match_data

      %i[year month day]
        .map { |m| match_data[m] }
        .join("-")
        .to_datetime
    end

    LOCATION_REGEX = %r{Locatie gevonden: (.+?)\.}

    def parse_location_found(description, storage_location)
      match_data = LOCATION_REGEX.match(description)
      return match_data[1].strip if match_data
      return storage_location&.strip&.titleize if storage_location.is_a?(String)

      %w[Name City]
        .map { |key| storage_location[key]&.strip&.titleize }
        .select(&:present?)
        .join(", ")
    end

    SERIAL_NUMBER_REGEX = %r{framenummer '(?:<strong>)?(.+)(?:</strong>)?'}

    def parse_serial_number(description)
      match_data = SERIAL_NUMBER_REGEX.match(description)
      return "absent" if match_data.blank? || absent?(match_data[1])
      match_data[1]
    end
  end
end
