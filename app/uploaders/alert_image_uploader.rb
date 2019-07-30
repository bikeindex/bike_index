class AlertImageUploader < ApplicationUploader
  include CarrierWave::MiniMagick
  include ::CarrierWave::Backgrounder::Delay

  def store_dir
    "#{base_store_dir}/#{model.id}"
  end

  def base_store_dir
    "uploads/#{model.class.to_s[0, 2]}"
  end

  def filename
    return if model.alert_image.blank?
    filename, _ = File.basename(model.alert_image.path, ".*").split("-")
    "#{filename}-alert.jpg"
  end

  def extension_white_list
    %w(jpg jpeg gif png tiff tif)
  end

  process :generate_alert_image
  process convert: "jpg"

  delegate :bike, to: :model

  def bike_url
    "bikeindex.org/bikes/#{bike.id}"
  end

  def bike_location
    city = model.city&.titleize
    state = model.state&.abbreviation&.upcase

    if city && state
      return "#{city}, #{state}"
    elsif state
      return state
    end

    registration_address = bike.registration_address.with_indifferent_access
    city = registration_address[:city]&.titleize
    state = registration_address[:state]&.upcase

    if city && state
      "#{city}, #{state}"
    elsif state
      state
    else
      ""
    end
  end

  def generate_alert_image
    AlertImageGenerator.generate_image(
      bike_image_path: model.alert_image.path,
      bike_url: bike_url,
      bike_location: bike_location,
      output_path: current_path,
    )
  end
end
