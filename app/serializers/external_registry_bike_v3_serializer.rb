class ExternalRegistryBikeV3Serializer < BikeV2Serializer
  delegate \
    :external_id,
    :location_found,
    :status,
    :url,
    to: :object,
    allow_nil: true

  def stolen
    object.stolen?
  end

  def status
    object.status&.titleize
  end

  def mnfg_name
    object.mnfg_name&.titleize
  end

  def frame_model
    object.frame_model&.titleize
  end

  def frame_colors
    object.frame_colors&.split(/\s*,\s*/)&.map(&:titleize)
  end

  def registry_name
    object.external_registry_name
  end

  def registry_url
    object.external_registry_url
  end

  def serial
    object.serial_number
  end

  def date_stolen
    object.date_stolen&.to_i
  end

  def year; end

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
