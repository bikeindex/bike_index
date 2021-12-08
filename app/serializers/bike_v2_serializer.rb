class BikeV2Serializer < ApplicationSerializer
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
    :stolen_coordinates,
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
    :status

  def serial
    object.serial_display
  end

  def manufacturer_name
    object.mnfg_name
  end

  def title
    object.title_string
  end

  def stolen
    object.status_stolen?
  end

  def date_stolen
    current_stolen_record&.date_stolen&.to_i
  end

  def thumb
    image = object.public_images&.first&.image_url(:small)
    return image if image.present?

    if object.stock_photo_url.present?
      small = object.stock_photo_url.split("/")
      ext = "/small_" + small.pop
      small.join("/") + ext
    end
  end

  def large_img
    object.public_images&.first&.image_url(:large).presence ||
      object.stock_photo_url
  end

  def url
    "#{ENV["BASE_URL"]}/bikes/#{object.id}"
  end

  def is_stock_img
    object.public_images.blank? && object.stock_photo_url.present?
  end

  def stolen_location
    current_stolen_record&.address_location(include_all: true)
  end

  def stolen_coordinates
    return nil unless current_stolen_record&.latitude_public&.present?
    [current_stolen_record.latitude_public, current_stolen_record.longitude_public]
  end

  private

  def current_stolen_record
    object.current_stolen_record
  end
end
