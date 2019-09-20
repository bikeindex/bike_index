class BikeV2Serializer < ActiveModel::Serializer
  attributes \
    :date_stolen,
    :description,
    :frame_colors,
    :frame_model,
    :id,
    :is_stock_img,
    :large_img,
    :location_found,
    :manufacturer_name,
    :external_id,
    :registry_name,
    :registry_url,
    :serial,
    :status,
    :stolen,
    :stolen_location,
    :thumb,
    :title,
    :url,
    :year

  attr_accessor \
    :location_found,
    :external_id,
    :registry_name,
    :registry_url,
    :status,
    :url

  def serial
    object.serial_display
  end

  def manufacturer_name
    object.mnfg_name
  end

  def title
    object.title_string
  end

  def date_stolen
    object.current_stolen_record && object.current_stolen_record.date_stolen.to_i
  end

  def thumb
    if object.public_images.present?
      object.public_images.first.image_url(:small)
    elsif object.stock_photo_url.present?
      small = object.stock_photo_url.split("/")
      ext = "/small_" + small.pop
      small.join("/") + ext
    end
  end

  def large_img
    if object.public_images.present?
      object.public_images.first.image_url(:large)
    elsif object.stock_photo_url.present?
      object.stock_photo_url
    end
  end

  def placeholder_image
    svg_path =
      Rails
        .application
        .assets["revised/bike_photo_placeholder.svg"]
        .digest_path

    "#{ENV["BASE_URL"]}/assets/#{svg_path}"
  end

  def url
    "#{ENV["BASE_URL"]}/bikes/#{object.id}"
  end

  def is_stock_img
    object.public_images.present? ? false : object.stock_photo_url.present?
  end

  def stolen_location
    object.current_stolen_record && object.current_stolen_record.address_short
  end
end
