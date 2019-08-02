class AlertImageUploader < ApplicationUploader
  include CarrierWave::MiniMagick
  include ::CarrierWave::Backgrounder::Delay

  alias stolen_record model
  delegate :bike, to: :stolen_record

  def store_dir
    "#{base_store_dir}/#{stolen_record.id}"
  end

  def base_store_dir
    "uploads/#{stolen_record.class.to_s[0, 2]}"
  end

  def filename
    return if stolen_record.alert_image.blank?
    file = File.basename(stolen_record.alert_image.path, ".*").chomp("-alert")
    "#{file}-alert.jpg"
  end

  def extension_white_list
    %w(jpg jpeg gif png tiff tif)
  end

  def bike_url
    "bikeindex.org/bikes/#{bike.id}"
  end

  def bike_location
    if stolen_record.address_location.present?
      stolen_record.address_location
    else
      bike.registration_location
    end
  end

  process :strip
  process :generate_alert_image
  process convert: "jpg"

  def generate_alert_image
    AlertImageGenerator.generate_image(
      bike_image_path: model.alert_image.path,
      bike_url: bike_url,
      bike_location: bike_location,
      output_path: current_path,
    )
  end
end
