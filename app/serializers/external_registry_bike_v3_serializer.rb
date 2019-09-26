class ExternalRegistryBikeV3Serializer < BikeV2Serializer
  delegate \
    :info_hash,
    :location_found,
    :external_id,
    :registry_name,
    :registry_url,
    :source_name,
    :source_unique_id,
    :status,
    :url,
    to: :object,
    allow_nil: true

  def serial
    object.serial_number
  end

  def date_stolen
    object.date_stolen&.to_i
  end

  def date_stolen_string
    object.date_stolen&.to_date&.to_s
  end

  def year; end

  def thumb
    object.image_url
  end

  def large_img
    object.image_url
  end

  def is_stock_img
    object.image_url.blank?
  end

  def stolen_location
    object.location_found.presence || "Unknown"
  end
end
