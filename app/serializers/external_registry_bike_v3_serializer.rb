class ExternalRegistryBikeV3Serializer < BikeV2Serializer
  delegate \
    :external_id,
    :location_found,
    :registry_name,
    :registry_url,
    :status,
    :url,
    to: :object,
    allow_nil: true

  def stolen
    object.stolen?
  end

  def serial
    object.serial_number
  end

  def date_stolen
    object.date_stolen&.to_i
  end

  def year
  end

  def thumb
    object.thumb_url
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
