class AlertImageUploader < ApplicationUploader
  include CarrierWave::MiniMagick
  include ::CarrierWave::Backgrounder::Delay

  alias stolen_record model

  def store_dir
    "#{base_store_dir}/#{stolen_record.id}"
  end

  def base_store_dir
    "uploads/#{stolen_record.class.to_s[0, 2]}"
  end

  def extension_white_list
    %w(jpg jpeg gif png tiff tif)
  end

  process :fix_exif_rotation
  process :strip
  process convert: "jpg"

  version :facebook do
    process generate_landscape: :facebook
    process resize_to_fill: [1200, 630]
  end

  version :twitter do
    process generate_landscape: :twitter
    process resize_to_fill: [1200, 600]
  end

  version :square do
    process :generate_square
    process resize_to_fill: [1200, 1200]
  end

  def generate_landscape(variant)
    Rails.logger.info "Processing #{variant} #{current_path}"
    manipulate! do |img|
      alert_image = AlertImageGenerator.new(stolen_record: stolen_record, bike_image: img)
      img = alert_image.build_landscape(variant)
    end
    Rails.logger.info "Finished #{variant} #{current_path}"
  end

  def generate_square
    Rails.logger.info "Processing square #{current_path}"
    manipulate! do |img|
      alert_image = AlertImageGenerator.new(stolen_record: stolen_record, bike_image: img)
      img = alert_image.build_square
    end
    Rails.logger.info "Finished square #{current_path}"
  end
end
