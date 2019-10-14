class ExternalRegistryBike::Project529Bike < ExternalRegistryBike
  def registry_name
    "Project529"
  end

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
    def build_from_api_response(attrs = {})
      return if attrs["status"]&.downcase == "recovered"

      bike = find_or_initialize_by(
        external_id: attrs["id"],
        serial_number: attrs["serial_number"],
        type: to_s,
      )

      bike.cycle_type = "bike"
      bike.status = attrs["status"]&.downcase
      bike.frame_model = attrs["model_string"]
      bike.mnfg_name = attrs["manufacturer_string"]
      bike.location_found = attrs.dig("active_incident", "location_address")
      bike.frame_colors = frame_colors(attrs)
      bike.description = description(attrs)
      bike.date_stolen = date_stolen(attrs)
      bike.country = country(attrs)
      bike.info_hash = info_hash(attrs)

      bike
    end

    private

    def info_hash(attrs)
      photo = primary_photo(attrs)

      {
        url: attrs["url"],
        image_url: photo["original_url"],
        thumb_url: photo["medium_url"],
      }
    end

    def country(attrs)
      name = attrs.dig("active_incident", "location_address")&.split(",")&.last
      Country.fuzzy_find(name)
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
      all_photos = attrs["bike_photos"].to_a

      photo =
        all_photos
          .select { |ph| ph["photo_type"].downcase.in?(["side"]) }.first ||
        all_photos
          .select { |ph| ph["photo_type"].downcase.in?(["what to look for"]) }.first ||
        all_photos
          .reject { |ph| ph["photo_type"].downcase.in?(["serial number", "shield"]) }.first

      photo || {}
    end
  end
end
