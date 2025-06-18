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
    :year,
    :propulsion_type_slug,
    :cycle_type_slug

  attr_accessor \
    :external_id,
    :registry_name,
    :registry_url

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

  def status
    object.status_humanized
  end

  def location_found
    return object.location_found if defined?(object.location)
    return nil unless object.status_impounded?
    object.address
  end

  def date_stolen
    current_stolen_record&.date_stolen&.to_i
  end

  def thumb
    @thumb ||= BikeService::Displayer.thumb_image_url(object)
  end

  def large_img
    object.image_url(:large).presence || object.stock_photo_url
  end

  def url
    object.html_url
  end

  def is_stock_img
    object.image_url.blank? && object.stock_photo_url.present?
  end

  def stolen_location
    current_stolen_record&.address
  end

  def stolen_coordinates
    return nil unless current_stolen_record&.latitude_public&.present?
    [current_stolen_record.latitude_public, current_stolen_record.longitude_public]
  end

  def propulsion_type_slug
    object.propulsion_type
  end

  def cycle_type_slug
    object.cycle_type
  end

  private

  def current_stolen_record
    object.current_stolen_record
  end
end
