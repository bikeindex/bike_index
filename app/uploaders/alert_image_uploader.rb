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
    "alert_#{model.id}.jpg"
  end

  def extension_white_list
    %w(jpg jpeg gif png tiff tif)
  end

  process :generate_alert_image
  process convert: "jpg"

  delegate :bike, to: :model

  def bike_image
    public_image = bike.public_images.first&.image
    raise ArgumentError, "No bike image for Bike #{bike.id}" if public_image.blank?
    public_image
  end

  def bike_url
    "bikeindex.org/bikes/#{bike.id}"
  end

  def bike_location
    city = bike.registration_address[:city]&.titleize
    state = bike.registration_address[:state]&.upcase

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
      bike_image_path: bike_image.path,
      bike_url: bike_url,
      bike_location: bike_location,
      output_path: current_path,
    )
  end
end
