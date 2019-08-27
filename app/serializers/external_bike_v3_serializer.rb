class ExternalBikeV3Serializer < ActiveModel::Serializer
  attributes \
    :date_stolen,
    :debug,
    :description,
    :frame_colors,
    :frame_model,
    :id,
    :is_stock_img,
    :large_img,
    :location_found,
    :manufacturer_name,
    :registry_id,
    :registry_name,
    :registry_url,
    :serial,
    :source_name,
    :source_unique_id,
    :status,
    :stolen,
    :stolen_location,
    :thumb,
    :title,
    :url

  delegate \
    :debug,
    :description,
    :location_found,
    :registry_id,
    :registry_name,
    :registry_url,
    :source_unique_id,
    :status,
    :url,
    :source_name,
    to: :object,
    allow_nil: true

  def serial
    object.serial_number
  end

  def manufacturer_name
    object.mnfg_name
  end

  def title
    object.title_string
  end

  def date_stolen
    object.date_stolen&.to_date&.to_s
  end

  def placeholder_image
    svg_path =
      Rails
        .application
        .assets["revised/bike_photo_placeholder.svg"]
        .digest_path

    "#{ENV["BASE_URL"]}/assets/#{svg_path}"
  end

  def thumb
    object.image_url || placeholder_image
  end

  def large_img
    object.image_url || placeholder_image
  end

  def is_stock_img
    object.image_url.blank?
  end

  def stolen_location
    object.location_found.presence || "Unknown"
  end
end
